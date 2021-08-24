+++
title = "Using intuition to avoid reading binary"
author = ["Petr Tikilyaynen"]
date = 2019-10-26T23:58:00+01:00
lastmod = 2019-10-26T23:59:16+01:00
tags = ["rust", "trading"]
categories = ["hacking"]
draft = false
description = "Trying to find meaning in 1s and 0s"
+++

In the previous write-up we found that the itchy parser failed to parse mostly
similar messages from 2 different market data files. The error appeared after successfully
parsing the same StockDirectory message in both cases.


## Using our intuition to read 1s and 0s {#using-our-intuition-to-read-1s-and-0s}

Let's examine the buffer which fails to parse and use some intuition to guess what it might be.

The last message was a StockDirectory message, which suggests that the next
message is likely to be another StockDirectory message.

To confirm this suspicion let's examine the buffer below.


### What curious properties can you see in the buffer below? {#what-curious-properties-can-you-see-in-the-buffer-below}

```diff
0                                                                  0
39                                                                 39
82                                                                 82
15                                                                 15
+78                                                                 106
0                                                                  0
0                                                                  0
10                                                                 10
+70                                                                 57
+215                                                                52
+12                                                                 21
+235                                                                128
+83                                                                 14
73                                                                 73
66                                                                 66
75                                                                 75
82                                                                 82
32                                                                 32
32                                                                 32
32                                                                 32
32                                                                 32
0                                                                  0
0                                                                  0
0                                                                  0
100                                                                100
78                                                                 78
67                                                                 67
90                                                                 90
32                                                                 32
80                                                                 80
78                                                                 78
32                                                                 32
49                                                                 49
78                                                                 78
0                                                                  0
0                                                                  0
0                                                                  0
0                                                                  0
78                                                                 78
0                                                                  0
39                                                                 39
```

"0 39" define the length of the following message.

The next byte is the message tag/type - 82 is "R" in ASCII, which is the code for a StockDirectory message.

Knowing that stock sybmol is a right-whitespace-padded alphabetic string of
eight ASCII characters helps us interpret "73 66 75 82 32 32 32 32", which appears in both buffers.

"32" is ASCII for whitespace.

"72 66 75 82" is "IBKR".

Looking up NASDAQ IBKR in your favourite search engine finds Interactive
Brokers, a company which changed its listing to the most recently opened trading
venue - Investors Exchange.

At the time of writing, itchy didn't have Investors Exchange as a variant of the MarketCategory enum

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MarketCategory {
    NasdaqGlobalSelect,
    NasdaqGlobalMarket,
    NasdaqCapitalMarket,
    Nyse,
    NyseMkt,
    NyseArca,
    BatsZExchange,
    Unavailable,
}
```

However, a PR with those changes has been opened on the repo. I recently opened
a PR that corrects the IssueSubTypes in the StockDirectory messages.


### Let's combine them! {#let-s-combine-them}

I created [a new branch](https://github.com/petr-tik/itchy-rust/tree/update%5Fitchy) that merges seanlane's changes with InvestorsExchange as a MarketCategory variant and mine outstanding PR.

Checking this branch out locally, so Cargo.toml builds the binary against it results in a panic free run through the market data file.

```bash
$$$$ cargo run -- 07302019.NASDAQ_ITCH50
    Finished dev [unoptimized + debuginfo] target(s) in 0.02s
     Running `target/debug/ob_visualiser 07302019.NASDAQ_ITCH50`
$$$$ echo $?
0
```


## So how quickly does it run? {#so-how-quickly-does-it-run}

Now that we fixed our fork of the itchy parsing library, we will remove all
debug prints from the library and compile our application with the "--release"
flag to measure maximum throughput.

We will also switch to dealing with unzipped, binary files to move gzip out of the hot path.

```rust
extern crate itchy;

use std::env::args;
use std::path::Path;
use std::time::Instant;

fn main() {
    let args: Vec<String> = args().collect();
    let path_to_market_data = Path::new(&args[1]);
    // allows us to pass the filename as an argument

    let stream = itchy::MessageStream::from_file(path_to_market_data).unwrap();
    let mut messages = 0;
    let start = Instant::now();
    for msg in stream {
        msg.unwrap();
        messages += 1;
    }
    let duration = Instant::now() - start;
    let speed = messages / duration.as_secs();
    println!(
        "Parsed {} messages in {:#?} at the rate of {} messages per second",
        messages, duration, speed
    );
}
```

Compile and run this executable and give it an unzipped market data file.

```bash
$$$$ cargo run --release -- 07302019.NASDAQ_ITCH50
   Compiling ob_visualiser v0.1.0 (/home/petr_tik/Coding/rust/ob_visualiser)
    Finished release [optimized] target(s) in 0.34s
     Running `target/release/ob_visualiser 07302019.NASDAQ_ITCH50`
Parsed 282229684 messages in 12.229675518s at the rate of 23519140 messages per second
```

In this example we can parse 23,519,140 messages per second or a message every 40 nanoseconds.
