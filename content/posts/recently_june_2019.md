+++
title = "Life recently"
author = ["Petr Tikilyaynen"]
date = 2019-06-04T00:01:00+01:00
lastmod = 2019-06-04T00:07:26+01:00
tags = ["thoughts"]
categories = ["hacking"]
draft = false
description = "What have I been up to recently?"
+++

Recently busy with many aspects of life: playing dinosaur with my nephew, suddenly having to look for a new flat, annoying admin things that involve people that ask for a lot of money for the right to chat to them.


## Leisurely reading {#leisurely-reading}

I have been consuming books from the Flashman series by George MacDonald Fraser: Flash for Freedom, Royal Flash, Flashman and the Dragon, Flashman at the Charge and Flashman and the Mountain of Light. I first read them when I was a teenager and have decided to re-read them to have a history refresher of the Victorian era. The author opted for a diary-style narrative that was written after Flashman had retired and later found in the attic of his family estate.

The combination of fascinating historical events, great writing style and humour makes them easy to read. The effort that went into referencing historical milestones (the betrayal of the Sikh army by its own Generals in 1847) and contemprorary observations (checkered vs striped trousers debate in 1840s) enables me to imagine myself next to Flashman in a Sikh torture dungeon, riding a troikas through freezing Russian wind and on a slave-running ship in the Atlantic.

The main difference between modern approach to history and the diary-style narrative is the racist language. Whenever I find myself chuckling to a Flashman passage in public, I worry that someone might look over my shoulder, see a racist word and assume I am reading enjoying **that**. While I don't condone Flashman's views on women and _foreigners_, I find it adds dimension to his personality and makes it even more cruel, when a foreign female plays a trick on him.


## How can I copy someone's writing style? {#how-can-i-copy-someone-s-writing-style}

Reading several books written in the same style piqued my interest in adopting or incorporating features from someone's style into my own. After a brief exchange with a friend, who has been thinking about similar ideas for his writing, I found myself researching "language style transfer" on Google Scholar. Style transfer on images has been solved to the extent that there are now Prisma and Instagram filters that turn your creative summer snaps into Van Gough-style vignettes. Implementing that on natural language is proving more difficult.

My research showed up 2 big problems:

1.  The difficulty of splitting form and meaning in text.

Most style transfer models assume we have different style functions, whose application on the underlying content yields different results.
In the realm of imagery, we can define objects as content and apply different styles to them to get different artefacts (impressionists or cubists drawing the same chair). Doing this in text suggests that we can distill text into the most compressed set of semantic objects. This presupposes natural language understanding that would enable us to summarise text and answer non-factual questions about it. We can either park this approach until we solve NLU or come up with a good enough heuristic to mimic content vs. form decoding.

1.  The absence of a framework to evaluate the quality of style transfer.

Research in text-to-speech has several wide-spread frameworks to score the quality of artefacts produced by a given system.


## Is it even possible to investigate language using language? {#is-it-even-possible-to-investigate-language-using-language}

This led to an interesting chat with a friend about the difficulty of reasoning about language using language.

Neural networks mimic the structure of the human brain, which captures non-linearity eg. activating brain regions by using different semantic categories. Language processing in the brain seems non-linear, yet human-made representations of language in writing is inherently linear. Maybe transferring concepts from own brain to someone else's brain linear language models, we lose dimensionality. At the same time, the practice of rubber duck debugging (explaining a problem to someone without context, like a dummy rubber duck) suggests the usefulness of externalising concepts in your brain into language.

Is there any research investigating the effect of externalising their thought process on people's ability to solve problems?

Below is a potential experiment set-up.
2 groups given the same problem:

1.  One has to do all the thinking in their head - cannot talk aloud.
2.  Explicitly given rubber ducks and told to talk through their thought process.
