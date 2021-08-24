+++
title = "Scratching NASDAQ's ITCH"
author = ["Petr Tikilyaynen"]
date = 2019-10-23T00:02:00+01:00
lastmod = 2019-10-23T01:11:44+01:00
tags = ["rust", "trading"]
categories = ["hacking"]
draft = false
description = "Joyfully debugging errors in binary parsers"
+++

I am building yet another order book tool in Rust, which
requires me to parse L3 (full) market data feed from NASDAQ.

In the words of one experienced trading systems developer `writing a feed
handler is boooooring, but does not build an order book`, so I searched if
someone else has implemented it already.

Thankfully, [adwhit has implemented a library to parse ITCH 5.0 feeds from files](https://github.com/adwhit/itchy-rust), which is one
line away from importing to my `Cargo.toml`.


## Getting and parsing market data {#getting-and-parsing-market-data}

I decided to have a look at the market data first.

Anyone can download a sample itch feed file from [NASDAQ's own ftp server](ftp://emi.nasdaq.com/ITCH/) to play around with (NB. they seem to limit the download speed).

I downloaded "07302019.NASDAQ\_ITCH50.gz", which was available at the time. Those
files are periodically updated, so if you are reading this later, don't expect
to find the same file on the ftp server.


## Parse market data or panic trying {#parse-market-data-or-panic-trying}

The itchy library has a user-friendly Readme that allows you to copy-paste a
code snippet that creates a stream of messages from a given file!

(According to GitHub, the author lives in London, so I would be happy to meet in
person and buy them a beverage of choice ****waves****.)

```rust
extern crate itchy;

fn main() {
   let stream = itchy::MessageStream::from_gzip("07302019.NASDAQ_ITCH50.gz").unwrap();
   for msg in stream {
     println!("{:?}", msg.unwrap());
   }
}
```

The results were not promising.

```bash
 $ RUSTC_WRAPPER= cargo run --release
    Compiling ob_visualiser v0.1.0 (/home/petr_tik/Coding/rust/ob_visualiser)
.
.
.
thread 'main' panicked at 'called `Result::unwrap()` on an `Err` value: Error(Msg("Parse failed: Switch"), State { next_error: None, backtrace: None })', src/libcore/result.rs:1084:5
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace.
```


## Hypotheses {#hypotheses}

I needed to find out the reason for failing.


### Corrupt market data file {#corrupt-market-data-file}

The downloaded market data file may have been corrupt. The ftp server provides
checksums for every archive. I checked it and found that the checksums matched.

Maybe, NASDAQ created and checksumed a file without checking its validity?


### Check another file {#check-another-file}

I decided to download and run the same application on another file - `12282018.NASDAQ_ITCH50.gz`.

```bash
 $ RUSTC_WRAPPER= cargo run --release
    Compiling ob_visualiser v0.1.0 (/home/petr_tik/Coding/rust/ob_visualiser)
.
.
.
thread 'main' panicked at 'called `Result::unwrap()` on an `Err` value: Error(Msg("Parse failed: Switch"), State { next_error: None, backtrace: None })', src/libcore/result.rs:1084:5
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace.
```

There is also a panic on the file.

They might have different reasons for failing though.


### Find the context for each failure {#find-the-context-for-each-failure}

To establish the context, I decided to:

1.  save and print the last successfully parsed message
2.  Give the state of the buffer on which parsing fails

<!--listend-->

```rust
extern crate itchy;

use std::env::args;
use std::path::Path;

fn main() {
    let args: Vec<String> = args().collect();
    let path_to_market_data = Path::new(&args[1]);
    // allows us to pass the filename as an argument

    let stream = itchy::MessageStream::from_gzip(path_to_market_data).unwrap();
    let mut last_msg: Option<itchy::Message> = None;
    for msg in stream {
        match msg {
            Ok(m) => {
                last_msg = Some(m);
            }
            Err(_e) => {
                dbg!(&last_msg);
            }
        }
    }
}
```

The pedantic reader might notice the code snippet above doesn't satisfy (2) and
doesn't print the state of the buffer.

Luckily, cargo makes it easy to monkey-patch our dependencies

First, git clone the itchy library locally and point cargo to the local copy instead of the one available on crates.io.

`/ob_visualiser/Cargo.toml`

```toml
[dependencies]
itchy = { path = "../itchy-rust/" }
```

Then, monkey patch your local copy of itchy-rust to print 50 bytes of the buffer
that failed to parse, before returning the error.

50 bytes is big enough to capture any NASDAQ ITCH 5.0 message, so we can examine it.

`/itchy-rust/src/lib.rs`

```rust
                Error(e) => {
                    // We need to inform user of error, but don't want to get
                    // stuck in an infinite loop if error is ignored
                    // (but obviously shouldn't fail silently on error either)
                    // therefore track if we already in an 'error state' and bail if so
                    if self.in_error_state {
                        return None;
                    } else {
                        self.in_error_state = true;
+                       #[cfg(debug_assertions)]
+                       {
+                           let offset_bigger_than_most_messages = 50;
+                           println!("{} bytes of the buffer", offset_bigger_than_most_messages);
+                           // print the buffer byte by byte split by newlines
+                           for c in &buf[..offset_bigger_than_most_messages] {
+                               println!("{:?}", c);
+                           }
+                       }
                        return Some(Err(format!("Parse failed: {}", e).into()));
                    }
```

Use a bit of bash magic to run the 2 binaries and produce results easy to review:

-   debug\_assertions prints to stderr, which we need to redirect to stdout with `2>&1`
-   `diff -ty` prints the result of 2 diffs side-by-side and turns tabs to spaces (cue flamewar) to make it easy to copy-paste.
-   `diff <x <y` is a convention to diff the stdout outputs of shell commands x and y.

<!--listend-->

```diff
$$$$ diff -ty <(2>&1 cargo -q run -- 12282018.NASDAQ_ITCH50.gz) <(2>&1 cargo -q run -- 07302019.NASDAQ_ITCH50.gz)
50 bytes of the buffer                                             50 bytes of the buffer
0                                                                  0
39                                                                 39
82                                                                 82
15                                                                 15
78                                                              |  106
0                                                                  0
0                                                                  0
10                                                                 10
70                                                              |  57
215                                                             |  52
12                                                              |  21
235                                                             |  128
83                                                              |  14
73                                                                 73
66                                                                 66
75                                                                 75
82                                                                 82
32                                                                 32
32                                                                 32
32                                                                 32
32                                                                 32
86                                                                 86
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
82                                                                 82
15                                                                 15
79                                                              |  107
0                                                                  0
0                                                                  0
10                                                                 10
70                                                              |  57
[src/main.rs:19] &last_msg = Some(                                 [src/main.rs:19] &last_msg = Some(
    Message {                                                          Message {
        tag: 82,                                                           tag: 82,
        stock_locate: 3917,                                     |          stock_locate: 3945,
        tracking_number: 0,                                                tracking_number: 0,
        timestamp: 11299371915896,                              |          timestamp: 11240803214263,
        body: StockDirectory(                                              body: StockDirectory(
            StockDirectory {                                                   StockDirectory {
                stock: "IBKCP   ",                                                 stock: "IBKCP   ",
                market_category: NasdaqGlobalSelect,                               market_category: NasdaqGlobalSelect,
                financial_status: Normal,                                          financial_status: Normal,
                round_lot_size: 100,                                               round_lot_size: 100,
                round_lots_only: false,                                            round_lots_only: false,
                issue_classification: PreferredStock,                              issue_classification: PreferredStock,
                issue_subtype: NotApplicable,                                      issue_subtype: NotApplicable,
                authenticity: true,                                                authenticity: true,
                short_sale_threshold: Some(                                        short_sale_threshold: Some(
                    false,                                                             false,
                ),                                                                 ),
                ipo_flag: Some(                                                    ipo_flag: Some(
                    false,                                                             false,
                ),                                                                 ),
                luld_ref_price_tier: Tier2,                                        luld_ref_price_tier: Tier2,
                etp_flag: Some(                                                    etp_flag: Some(
                    false,                                                             false,
                ),                                                                 ),
                etp_leverage_factor: 0,                                            etp_leverage_factor: 0,
                inverse_indicator: false,                                          inverse_indicator: false,
            },                                                                 },
        ),                                                                 ),
    },                                                                 },
)                                                                  )
```

Because of the order, debug\_assertions in the itchy library prints the buffer before our binary prints the last parsed message.


### Examining the results {#examining-the-results}

The last successfully parsed message is the StockDirectory message related to
the same company - IBKCP. The only differences are stock\_locate (day-specific id of
instrument) and timestamp, as expected.

The first 4 bytes are identical, followed by one different byte,
followed by mostly matching bytes.

This is a stronger indicator that the itch parser doesn't support some message types.

Stay tuned for more parser-monkey-patching and binary-file-diffing!

> As an aside, my first method of examining the buffer for a failed parse
> was to run gdb, wait for a panic and then recover the state of the buffer.
>
> It involved more steps and had an ncurses UI and a suboptimal UX.
>
> Print debugging is much nicer in this case.
