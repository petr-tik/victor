---
title: "Compiling a Rust library to wasm"
date: "2018-09-30"
categories: hacking
draft: false
tags: 
 - rust
 - wasm
Author: Petr Tikilyaynen
description:  "Going down rabbit holes of conditional compilation"
---

Since finding Paul Masurel's [tantivy searching/indexing library](https://github.com/tantivy-search/tantivy/), I thought it would be cool to make the library available for the browser. The rust-wasm WG is working on tooling, which simplifies solving this problem.

## Intended design of tantivy

I want to make it possible to compile tantivy:

 1. As a wasm library to ship to the browser
 2. As the usual server-side indexer + serialiser

### wasm library

Will load and deserialise the index from a binary file sent to the browser. After an index is instantiated, wasm will process recieve queries from javascript, process them using the index loaded earlier and return results back to javascript to present to the user.

### Indexer + serialiser

The indexer will remain same as before. When indexing is over, walk over the index directory and build a binary file.

### Advantages of this design

Sharing code, testing and building the same library, so we can guarantee that an index built and serialised on the server will be deserialised and give the same results in the client.

### Disadvantages

Compiling for wasm is hard, because it requires that all dependencies and their dependencies (recursively) can compile to wasm. The library is most likely going to take a lot of space on disk.

## Other design aims

Use cargo and conditional compilation to the max to find efficiency gains and minimise both server- and wasm library size.

# Sunday afternoon debugging session

Below is the description of my Sunday afternoon spent trying to build tantivy for the wasm target. First working with the current version of tantivy, then an exploration of Paul's previous effort. I found the dependencies, whose dependencies break the compilation for the wasm target and outlined plans for future work. 

## Directory layout

Using tantivy library after version 0.7.0, I created a `wasm` sub-directory in the root directory of `tantivy`. 

```bash
tantivy$$$ tree -L 1 wasm/
wasm/
├── Cargo.lock
├── Cargo.toml
├── rust-toolchain
├── src/
├── target/
└── wasm-pack.log
```

I took Paul's earlier effort to build a wasm-ready tantivy searcher in an older wasm branch. He based his branch off tantivy v0.5.0. so I expect that the library will need new code to compile again.

### Why not make a new directory/crate and import tantivy in Cargo? 

While it might seem easier to create a new project and import tantivy, I expect this work to require changes in the tantivy library, so best keep the directories nested together. 

### I'm bringing s.... StaticDirectory back

Paul's previous attempt to compile tantivy for wasm included an abstraction called `StaticDirectory`. By the time we got to v0.7.0, StaticDirectory disappeared and was replaced by several other directories inside the `directory` module. Using StaticDirectory inside the `wasm/lib/src.rs` didn't compile, because tantivy didn't have StaticDirectory anymore. Having wasm as a subdirectory inside tantivy allowed me to add a StaticDirectory to the `tantivy` library. 

After getting the `tantivy` library to compile for normal target with StaticDirectory, I went to the `wasm/` directory to compile the release version for wasm32 using nightly version of the compiler.

```bash
cd wasm/
wasm$$$ /home/petr_tik/.cargo/bin/cargo +nightly build --release --target wasm32-unknown-unknown
   Compiling memmap v0.6.2
   Compiling utf8-ranges v1.0.1
   Compiling safemem v0.3.0
   Compiling bit-vec v0.5.0
error[E0433]: failed to resolve. Use of undeclared type or module `MmapInner`
   --> /home/petr_tik/.cargo/registry/src/github.com-1ecc6299db9ec823/memmap-0.6.2/src/lib.rs:188:9
    |
188 |         MmapInner::map(self.get_len(file)?, file, self.offset).map(|inner| Mmap { inner: inner })
    |         ^^^^^^^^^ Use of undeclared type or module `MmapInner`

error[E0433]: failed to resolve. Use of undeclared type or module `MmapInner`
   --> /home/petr_tik/.cargo/registry/src/github.com-1ecc6299db9ec823/memmap-0.6.2/src/lib.rs:198:9
    |
198 |         MmapInner::map_exec(self.get_len(file)?, file, self.offset)
    |         ^^^^^^^^^ Use of undeclared type or module `MmapInner`

error[E0433]: failed to resolve. Use of undeclared type or module `MmapInner`
   --> /home/petr_tik/.cargo/registry/src/github.com-1ecc6299db9ec823/memmap-0.6.2/src/lib.rs:237:9
    |
237 |         MmapInner::map_mut(self.get_len(file)?, file, self.offset)
    |         ^^^^^^^^^ Use of undeclared type or module `MmapInner`

error[E0433]: failed to resolve. Use of undeclared type or module `MmapInner`
   --> /home/petr_tik/.cargo/registry/src/github.com-1ecc6299db9ec823/memmap-0.6.2/src/lib.rs:267:9
    |
267 |         MmapInner::map_copy(self.get_len(file)?, file, self.offset)
    |         ^^^^^^^^^ Use of undeclared type or module `MmapInner`

error[E0433]: failed to resolve. Use of undeclared type or module `MmapInner`
   --> /home/petr_tik/.cargo/registry/src/github.com-1ecc6299db9ec823/memmap-0.6.2/src/lib.rs:280:9
    |
280 |         MmapInner::map_anon(self.len.unwrap_or(0), self.stack).map(|inner| MmapMut { inner: inner })
    |         ^^^^^^^^^ Use of undeclared type or module `MmapInner`

error[E0412]: cannot find type `MmapInner` in this scope
   --> /home/petr_tik/.cargo/registry/src/github.com-1ecc6299db9ec823/memmap-0.6.2/src/lib.rs:310:12
    |
310 |     inner: MmapInner,
    |            ^^^^^^^^^ not found in this scope

error[E0412]: cannot find type `MmapInner` in this scope
   --> /home/petr_tik/.cargo/registry/src/github.com-1ecc6299db9ec823/memmap-0.6.2/src/lib.rs:425:12
    |
425 |     inner: MmapInner,
    |            ^^^^^^^^^ not found in this scope

error: aborting due to 7 previous errors
error: Could not compile `memmap`.
```

The `memmap` dependency of tantivy wasn't compiling, which broke the build of wasm. I first needed to compile `tantivy` for the wasm target. 

### Where did memmap come from? 

my `wasm/src/lib.rs` file had minimal dependencies, so memmap wasn't a problem with wasm-bindgen or my wasm crate. 

Examining the root `Cargo.toml` I couldn't find memmap as a dependency there either. 

### If memmap isn't a dependency in Cargo.toml, why is it breaking my build? 

This suggested that memmap may be a dependency of another dependency.

![Photo](/images/dicaprio.jpeg)

I looked for files using mmap features and what crates those files import. Grep for all files that use `mmap`, removing files that never use it and sorting by the number of matching lines suggests `directory` module is the biggest culprit. 

```bash
$$$$$ grep -rc "mmap" src/* | grep -v ":0" | sort -rn -k2 -t ':'
src/directory/mmap_directory.rs:45
src/directory/managed_directory.rs:15
src/core/index.rs:10
src/directory/read_only_source.rs:8
src/directory/mod.rs:8
src/termdict/termdict.rs:3
src/lib.rs:2
src/store/mod.rs:1
src/functional_test.rs:1
src/core/segment_reader.rs:1
```

one of the imports in `src/directory/mmap_directory.rs` is `use fst::raw::MmapReadOnly;`, whose name correctly suggests it uses memmap features. Looking inside `memmap-0.6.2/lib.rs` shows it's configured to build for unix or windows. Building for the wasm target misses all calls to macros below

```rust
[cfg(windows)]
```
and the crate fails to compile.

## How did Paul compile tantivy to wasm back in the days of v0.5.0?

I decided to go back to Paul's wasm branch based off v0.5.0 release and see if it would compile to wasm target without problems with memmap. There was a problem with the bitpacking crate, whose dependency was a path "../bitpacking". Paul must have developed it locally at the time. Changing bitpacking as below, before building core tantivy for wasm.

```bash
-bitpacking = {path = "../bitpacking"}
+bitpacking = "*"
```

Building with nightly failed because of a difference in standard library between the nightlies Paul used at the time and the one I am using now. 

```
$$$$ cargo +nightly build --verbose --release --no-default-features --target wasm32-unknown-unknown

error[E0432]: unresolved import `std::collections::range`                                                                                                                    
  --> src/query/range_query.rs:11:23                                                                                                                                         
   |                                                                                                                                                                         
11 | use std::collections::range::RangeArgument;                                                                                                                             
   |                       ^^^^^ Could not find `range` in `collections`                                                                                                     
```

I needed to decide if I should investigate how to compile old version of wasm branch, which didn't seem to have memmap issues or go back to my branch based on the most recent release of tantivy. 

## How hard can it be to compile an old version? 

Removing `range_query` and associated imports seemed to have helped to compile tantivy to wasm. Although compilation ends successfully, only a binary file is compiled to .wasm file in the target directory.

The only .wasm file in the target directory was for a bin package. 


## Would adding a file with wasm bindings to bin help solve the problem? 

I tried compiling and it gave me new errors, so I decided to stop making an old version of the library compile.

![cute otter](/images/otter.jpg)

I was getting tired and decided to try the ot[t|h]er method that I originally decided against.

## Back to current version of tantivy and the wonders of memmap

I have now decided to solve the problem of memmap breaking compilation for wasm. 

## What are the next steps?

Find all dependencies that use memmap.
    
Find all files that import and use those dependencies. 
    
Record and trace full call stack of functions called when a query is processed as described in the wasm query function. Use this information to conditionally compile that call stack with fewer imports.
    

If you have any ideas - give me a shout.
