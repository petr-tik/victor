+++
title = "Don't mistake file permissions for read-only fs mounts"
author = ["Petr Tikilyaynen"]
date = 2019-06-16T22:57:00+01:00
lastmod = 2019-06-16T23:46:25+01:00
tags = ["rust", "tantivy"]
categories = ["hacking"]
draft = false
description = "Hunting a bug down in tantivy"
+++

I enjoy contributing to [tantivy](https://github.com/tantivy-search/tantivy/), a Lucene-like library in Rust.

If you are building indexers or applications that need text search - check it out!

In my opinion, one of the most important tasks is collecting feature requests and bug reports from a growing number of users to a) show that we care b) build a product that people want.

Recently one of our early adopters ran into a problem, while deploying a tantivy application to a read-only filesystem.

I picked up the [issue](https://github.com/tantivy-search/tantivy/issues/557) and decided to build a repro.
Below is my journey, which I intend to finish by adding read-only mode, which will enable people to deploy tantivy-based applications to serve static indexes.


## Reproducing the bug locally {#reproducing-the-bug-locally}


### Create an index in a new directory {#create-an-index-in-a-new-directory}

Most tantivy examples use transient TempDir or RAMDirectory abstractions that disappear without creating a tantivy index directory.

We need to write a programme that will persist a tantivy index to a directory.

<a id="code-snippet--examples-write-index.rs"></a>
```rust
#[macro_use]
extern crate tantivy;
use std::fs::create_dir;
use std::path::Path;
use tantivy::schema::*;
use tantivy::Index;

fn main() -> tantivy::Result<()> {
    let mut schema_builder = Schema::builder();

    schema_builder.add_text_field("title", TEXT | STORED);
    schema_builder.add_text_field("body", TEXT);
    let schema = schema_builder.build();
    let index_path = Path::new("small_index/");
    create_dir(index_path)?;
    let index = Index::create_in_dir(&index_path, schema.clone())?;

    let mut index_writer = index.writer(50_000_000)?;

    let title = schema.get_field("title").unwrap();
    let body = schema.get_field("body").unwrap();

    let mut old_man_doc = Document::default();
    old_man_doc.add_text(title, "The Old Man and the Sea");
    old_man_doc.add_text(
        body,
        "He was an old man who fished alone in a skiff in the Gulf Stream and \
         he had gone eighty-four days now without taking a fish.",
    );

    // ... and add it to the `IndexWriter`.
    index_writer.add_document(old_man_doc);

    // For convenience, tantivy also comes with a macro to
    // reduce the boilerplate above.
    index_writer.add_document(doc!(
    title => "Of Mice and Men",
    body => "A few miles south of Soledad, the Salinas River drops in close to the hillside \
            bank and runs deep and green. The water is warm too, for it has slipped twinkling \
            over the yellow sands in the sunlight before reaching the narrow pool. On one \
            side of the river the golden foothill slopes curve up to the strong and rocky \
            Gabilan Mountains, but on the valley side the water is lined with trees—willows \
            fresh and green with every spring, carrying in their lower leaf junctures the \
            debris of the winter’s flooding; and sycamores with mottled, white, recumbent \
            limbs and branches that arch over the pool"
    ));

    // Multivalued field just need to be repeated.
    index_writer.add_document(doc!(
    title => "Frankenstein",
    body => "You will rejoice to hear that no disaster has accompanied the commencement of an \
             enterprise which you have regarded with such evil forebodings.  I arrived here \
             yesterday, and my first task is to assure my dear sister of my welfare and \
             increasing confidence in the success of my undertaking."
    ));

    match index_writer.commit() {
        Ok(_op) => {
            println!("Successfully commit index at {:?}", index_path);
        }
        Err(e) => {
            println!("Failed to commit with err: {}", e);
        }
    };

    Ok(())
}
```

Compile the example, run it and check that index files have been persisted.

```bash
 $$$$ cargo build --example write_index
   Finished dev [unoptimized + debuginfo] target(s) in 5.09s
$$$$ ./target/debug/examples/write_index
 Successfully commit index at "small_index/"
 $$$$ ls -a small_index
 .                                           a9831bbd86194aeb8d131a8f420cd5a9.store
 ..                                          a9831bbd86194aeb8d131a8f420cd5a9.term
 8ce15f10c1394562b36b4f99d81252cb.fast       c01908e4fbb4431e9e3b75a0a0be8f61.fast
 8ce15f10c1394562b36b4f99d81252cb.fieldnorm  c01908e4fbb4431e9e3b75a0a0be8f61.fieldnorm
 8ce15f10c1394562b36b4f99d81252cb.idx        c01908e4fbb4431e9e3b75a0a0be8f61.idx
 8ce15f10c1394562b36b4f99d81252cb.pos        c01908e4fbb4431e9e3b75a0a0be8f61.pos
 8ce15f10c1394562b36b4f99d81252cb.posidx     c01908e4fbb4431e9e3b75a0a0be8f61.posidx
 8ce15f10c1394562b36b4f99d81252cb.store      c01908e4fbb4431e9e3b75a0a0be8f61.store
 8ce15f10c1394562b36b4f99d81252cb.term       c01908e4fbb4431e9e3b75a0a0be8f61.term
 a9831bbd86194aeb8d131a8f420cd5a9.fast       .managed.json
 a9831bbd86194aeb8d131a8f420cd5a9.fieldnorm  meta.json
 a9831bbd86194aeb8d131a8f420cd5a9.idx        .tantivy-meta.lock
 a9831bbd86194aeb8d131a8f420cd5a9.pos        .tantivy-writer.lock
 a9831bbd86194aeb8d131a8f420cd5a9.posidx
```


### Create a reader application {#create-a-reader-application}

As the ticket states, opening in a given directory throws the error, so we only
need a small application to check `Index::open_in_dir`.

<a id="code-snippet--examples-open-in-dir.rs"></a>
```rust
extern crate tantivy;
use tantivy::Index;

fn main() -> tantivy::Result<()> {
    let idx_path = "small_index/";
    let _index = match Index::open_in_dir(idx_path) {
        Ok(_idx) => {
            println!("Successfully opened the index");
        }
        Err(err) => {
            println!("Failed to open index at {} with error: {}", idx_path, err);
        }
    };
    Ok(())
}
```

Compiling an example gives us a debug build binary in `target/debug/examples`

```bash
$$$$ cargo build --example open_in_dir
Finished dev [unoptimized + debuginfo] target(s) in 0.19s
```


### Set read-only permissions to all index files {#set-read-only-permissions-to-all-index-files}

Do that by removing any <code>w</code>rite or e<code>x</code>ecute  permissions from all files in the `small_index` directory.

```bash
$$$$ sudo chmod a-wx small_index/* small_index/.managed.json small_index/.tantivy-*
$$$$ ls -als small_index/
total 100
4 drwxrwxr-x  2 petr_tik petr_tik 4096 Jun 16 19:38 .
4 drwxrwxrwx 11 petr_tik petr_tik 4096 Jun 16 19:38 ..
4 -r--r--r--  1 petr_tik petr_tik    5 Jun 16 19:38 8ce15f10c1394562b36b4f99d81252cb.fast
4 -r--r--r--  1 petr_tik petr_tik   19 Jun 16 19:38 8ce15f10c1394562b36b4f99d81252cb.fieldnorm
4 -r--r--r--  1 petr_tik petr_tik   91 Jun 16 19:38 8ce15f10c1394562b36b4f99d81252cb.idx
4 -r--r--r--  1 petr_tik petr_tik  145 Jun 16 19:38 8ce15f10c1394562b36b4f99d81252cb.pos
4 -r--r--r--  1 petr_tik petr_tik   27 Jun 16 19:38 8ce15f10c1394562b36b4f99d81252cb.posidx
4 -r--r--r--  1 petr_tik petr_tik   76 Jun 16 19:38 8ce15f10c1394562b36b4f99d81252cb.store
4 -r--r--r--  1 petr_tik petr_tik  446 Jun 16 19:38 8ce15f10c1394562b36b4f99d81252cb.term
4 -r--r--r--  1 petr_tik petr_tik    5 Jun 16 19:38 a9831bbd86194aeb8d131a8f420cd5a9.fast
4 -r--r--r--  1 petr_tik petr_tik   19 Jun 16 19:38 a9831bbd86194aeb8d131a8f420cd5a9.fieldnorm
4 -r--r--r--  1 petr_tik petr_tik  115 Jun 16 19:38 a9831bbd86194aeb8d131a8f420cd5a9.idx
4 -r--r--r--  1 petr_tik petr_tik  113 Jun 16 19:38 a9831bbd86194aeb8d131a8f420cd5a9.pos
4 -r--r--r--  1 petr_tik petr_tik   27 Jun 16 19:38 a9831bbd86194aeb8d131a8f420cd5a9.posidx
4 -r--r--r--  1 petr_tik petr_tik   65 Jun 16 19:38 a9831bbd86194aeb8d131a8f420cd5a9.store
4 -r--r--r--  1 petr_tik petr_tik  649 Jun 16 19:38 a9831bbd86194aeb8d131a8f420cd5a9.term
4 -r--r--r--  1 petr_tik petr_tik    5 Jun 16 19:38 c01908e4fbb4431e9e3b75a0a0be8f61.fast
4 -r--r--r--  1 petr_tik petr_tik   19 Jun 16 19:38 c01908e4fbb4431e9e3b75a0a0be8f61.fieldnorm
4 -r--r--r--  1 petr_tik petr_tik  189 Jun 16 19:38 c01908e4fbb4431e9e3b75a0a0be8f61.idx
4 -r--r--r--  1 petr_tik petr_tik  161 Jun 16 19:38 c01908e4fbb4431e9e3b75a0a0be8f61.pos
4 -r--r--r--  1 petr_tik petr_tik   27 Jun 16 19:38 c01908e4fbb4431e9e3b75a0a0be8f61.posidx
4 -r--r--r--  1 petr_tik petr_tik   68 Jun 16 19:38 c01908e4fbb4431e9e3b75a0a0be8f61.store
4 -r--r--r--  1 petr_tik petr_tik 1022 Jun 16 19:38 c01908e4fbb4431e9e3b75a0a0be8f61.term
4 -r--r--r--  1 petr_tik petr_tik  872 Jun 16 19:38 .managed.json
4 -r--r--r--  1 petr_tik petr_tik  814 Jun 16 19:38 meta.json
0 -r--r--r--  1 petr_tik petr_tik    0 Jun 16 19:38 .tantivy-meta.lock
0 -r--r--r--  1 petr_tik petr_tik    0 Jun 16 19:38 .tantivy-writer.lock
```

Run the open\_in\_dir application and expect an error!

```bash
$$$$ ./target/debug/examples/open_in_dir
Successfully opened the index
```


### Directory permissions != file permissions {#directory-permissions-file-permissions}

Reviewing the output of last ls command again we notice that the `small_index` directory retains write and execute permissions.

```bash
$$$$ ls -als small_index/
total 100
4 drwxrwxr-x  2 petr_tik petr_tik 4096 Jun 16 19:38 .
```

This suggests that removing write and execute permissions from all the <span class="underline">files</span> in the directory doesn't prevent us from opening the index.

Let's try removing write and execute permissions from the directory and see what happens.

```bash
$$$$ sudo chmod a-wx small_index/
$$$$ sudo ls -als small_index/
total 100
4 dr--r--r--  2 petr_tik petr_tik 4096 Jun 16 19:38 .
...
$$$$ ./target/debug/examples/open_in_dir
Failed to open index at small_index/ with error: An IO error occurred: 'io error occurred on path '".managed.json"': 'Permission denied (os error 13)''
```

{{< figure src="/images/bingo2.gif" >}}


### What have we found? {#what-have-we-found}

My repro has shown that for `Index::open_in_dir` to work all index files can have read-only file permissions, as long as the index directory retains write and execute permissions.

As soon as you remove those permissions from the index directory, you get an error with OS code 13 on Linux.


### So I can reproduce the bug, right? {#so-i-can-reproduce-the-bug-right}

No.

The issue quotes a different error code.

> "Read-only file system"


## Go deeper {#go-deeper}

Setting file or directory permissions with `chmod` doesn't give us a repro of the environment, because my file system remains read and write. I made the mistake of conflating `chmod` settings with file systems settings.

We need to simulate a read-only file system to reproduce this error.

In the next episode, I will outline my attempt to simulate a read-only filesystem with Docker.
