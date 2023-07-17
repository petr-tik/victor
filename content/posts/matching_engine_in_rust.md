---
title: "Rust - from 0 to productive in 2 weeks"
date: "2019-01-19"
categories: hacking
draft: false
tags: 
 - rust
Author: Petr Tikilyaynen
description: "Implementing an order book in Rust"
---


This is a story of me going from making sarcastic jokes about rewriting everything in Rust to ~~becoming one of them~~ growing to like the language. 

I found a C++17 implementation of an order book (a common take home exercise for interviews with trading firms) and decided to implement a solution in Rust. Following getting started tutorials, documentation and using great tooling, I found myself becoming productive in the language. Profiling and optimising the application allowed me to learn more about Rust data structures. It beat the C++ implementation on benchmarks. Full disclosure - I don't think the author of the C++ version spent much time optimising it. 

[Here is the code](https://github.com/petr-tik/dark_rusty_pool)

### Why did you do it?

People who know me well could confirm my smugness when discussing Rust and its powerful advocacy in the developer community at the start of 2018. My goto suggestion was to rewrite your application in Rust, because it would "solve all your problems". After I watching rust evangelists on twitter, I decided to be more open-minded and use the language for a small project, instead of continusly making fun of it. 

### What is an order book? 

An order book is an application that stores buy and sell orders for different securities (shares, derivatives, other financial instruments). Institutions that engage in electronic trading have an implementation of an order book in their systems. Exchanges and market makers, which effectively run their own exchanges, are legally obliged to guarantee the best execution according to price-time priority. Keeping orders in an order book allows them to guarantee best execution and efficiently process thousands of entries per second. Clients of exchanges - brokers or individual investors - also run an order book to represent the state of the market. They can use it to find trading opportunities or implement their own ways of publishing orders to different exchanges. 

The requirements for such distributed fault-tolerant and low latency. (I think I got all the buzzwords in). 

If you want to learn the structure of big boy exchanges - watch [Brian Nigito's talk](https://www.youtube.com/watch?v=b1e4t2k2KJY). 


### So, did you build a trading system? 

If I had, I would be writing this from my house in Mexico between playing beach volleyball and surfing. 

I implemented an order book for one unnamed security. The biggest differences between my order book and grown-up exchanges are: OB doesn't match orders across buy and sell sides, OB isn't distributed and my OB handles one financial product. 

The order book can add new orders and reduce the size of existing orders. It receives orders as multi-line input on stdin. If at any point, there are more bids (buy orders) or asks (sell orders) than the target\_size, print a summary to stdout.


### What made you so productive in Rust? 

#### rustfmt (nee cargo-fmt)

I enjoy using an opinionated linter. It solves the problem of inconsistency between collaborators and across projects. Not only does it stop bickering between programmers, it also lifts my mental burden of getting used to different styles of Rust. After integrating into your IDE, you will have your .rs files formatted on every save. 


#### Derive Love

The rust compiler allows you to shortcut generating boilerplate for your custom types. I was working with a type that featured as a key in an ordered map (BTreeMap) and unordered map (HashMap). The type was a wrapper around i64. The derive(Hash) macro generated the Hash `Trait` (interface). 

Compiler unwraps Amount into underlying i64 and implements traits for the struct to be used in HashMap and BTreeMap (needs ordering)


```rust
#[derive(Copy, Clone, Debug, Eq, Hash, PartialEq, PartialOrd, Ord)] 
pub struct Amount {
    pub as_int: i64,
}
```

For me the biggest gain wasn't saving time to type lines of code. The opportunity to continue solving the problem of storing an ordered collection of amounts without context switching to implement hashing was the winner for me. Later I needed to implement a custom way of ordering amounts. 

There was only one minor downside, less related to the language and more to my laziness. The immediate feeling of proficiency with auto-complete gave me an illusion that I know rust APIs and can write them from memory. 

### What made your implementation efficient? 

This should be another post on its own. I will leave a teaser here and write something up, if people really want to know. 

Tricks that helped performance:
    * Replaced `println!` with a stdout lock and `writeln!`
    * Enabled LTO in Cargo.toml and pre-allocated all heap-based data structures.
    * Replaced BTreeMap with a memory-contiguous vector, which implements its own ordering using ... binary search.
    * Used llvm-profdata and rustc nightly, ran the application for PGO. Didn't get a meaningful improvement. 


Correcting my own design blunders (infinite source of optimisations:
    * Turned timestamps into ints instead of using heap-allocated strings.
    

### So, should we rewrite everything in Rust? 

The rust compiler, tooling (racer, completion, clippy) and the culture of thorough documentation made it easy for me to become immediately productive. Helpful error messages with detailed explanations of language concepts helped me learn, while solving problems. 

Recently, I have noticed fewer calls/posts/tweets calling people to rewrite critical pieces of infrastructure in Rust. Ironically, as the Rust strike force grew more level-headed, I became more of an ardent advocate for the language.

Bryan Cantrill expressed a view that I have now adopted. Rust should continue to emphasise its usefulness for *new* projects in systems engineering. The sunk cost of 1000s of programmer-hours has given us OSes like Linux, BSD and Emacs; database engines like sqlite and postgres and web servers like nginx. 

Taking another 1000s of hours to rewrite *only* (weekend project anyone?) one of them in Rust will not help anyone. Contributors to those projects, who have accumulated domain expertise, are unlikely to solve the same problem, just because they can use a new language. Most experienced systems programmers have already etched into their brain a version of the ownership system. 

Organisations using such systems in the critical path are not going to fix what isn't broken. Users of the end product won't care, if the sqlite they are running on their Android phone is now in Rust. 

Instead we should leverage the expressiveness of the language, the ease of use helped by great tools and good FFI support to solve new problems. We should praise the work of systems programmers, whose products are powering most of our infrastructure and work together with them. 


<!--  LocalWords:  dr
 -->
