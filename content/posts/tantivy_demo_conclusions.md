+++
title = "Takeaways from my tantivy talk"
author = ["Petr Tikilyaynen"]
date = 2019-10-01T22:51:00+01:00
lastmod = 2019-10-15T22:49:54+01:00
tags = ["tantivy"]
categories = ["hacking"]
draft = false
description = "What I learnt after talking about tantivy"
+++

I spoke about tantivy at the Rust London meetup last week ([video](https://www.youtube.com/watch?v=sAARzvm1psk)). My intention was to introduce Rust-curious people to tantivy and outline its features, so people can decide if it can help them solve problems.


## Planned and executed well {#planned-and-executed-well}

-   Defined the problem space and showed a diagram to give a high-level overview of what a search and indexing library does.
-   Showing a basic demo proved it’s a real project. Using Python for the demo,
    made it accessible to more people without scaring them with loads of Rust code
    and a long recompile cycle.
-   Using 10 slides with a demo in the middle kept it snappy and mostly
    interactive.
-   It was great to have so many attendees at the meetup and nearly a dozen
    people asking questions immediately after the presentation and at the end
    of the meetup.
-   Managing people’s expectations by acknowledging the weaknesses of tantivy, the Rust
    ecosystem and noticeably long compile times.


## Planned but didn’t execute {#planned-but-didn-t-execute}

-   Start with definitions
-   Missed one of my prepared puns.
-   Missed the opportunity to present facts about tantivy – tables or graphs speak louder than words. Show benchmark results and a plot.


## Future work {#future-work}

-   Start with a concrete problem that engages the highest possible number of listeners.
-   Come up with a richer corpus with a variety of fields (ints, floats, text, tags), where non-trivial queries give interesting results (property ads, restaurant menus).
-   Collect questions from the audience and add them to the central FAQ


## Friends' feedback {#friends-feedback}

-   Too much text on slides
-   Didn't understand what a schema was - define a schema and give an example
-   Show the input data first, its structure, explain why the structure matters.
-   Compare to other approaches (like grep), explain why this is better
-   Too much fluff about Rust
-   Using Python for the demo makes the demo code shorter and more accessible.
