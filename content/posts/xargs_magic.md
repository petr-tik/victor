---
title: "How to update your changelog automatically"
date: "2019-01-01"
category: hacking
draft: false
tags: [bash, git]
author: Petr Tikilyaynen
description:  "The magic of xargs and git log"
---

If you ever needed a quick way to update your changelog - you should find the post below interesting. 

## How did I get here?

I have been using the SurfingKeys extension for Chrome and Firefox (thanks again for a great extension + shout-outs below). 

After a recent update to 0.9.42, I clicked on the changelog option in browser and realised that the last version summarised in the changelog was 0.9.30. 

All of development takes place on GitHub, so it is easy to fork and prepare a PR. 

## How do you summarise changes since a given version? 

I needed to populate the changelog with all changes that have been committed since the last time the changelog was updated. The last tag was 0.4.1, so instead of using git tags, I needed to find another way. 

So I wrote a bash script to dump a summary of all commits between last version in the changelog and current git HEAD. 

Here it is in all its splendour. 

```bash
grep -oP -m1 "(?## )[0-9].+" pages/changelog.md | xargs -I LAST_VERSION git log --format="%H" --grep="LAST_VERSION" | xargs -I COMMIT_HASH git log --format=%s%n%b COMMIT_HASH..HEAD
```

Let's break it down into constituent parts. 

## Step one - find the latest version in the changelog

`grep -oP -m1 "(?## )[0-9].+" pages/changelog.md`

Finds the first match (`-m1`) of the given regex in the changelog file. The changelog file is written in reverse chronological order, so the first entry is the latest version. 

`-oP` enables me to ignore the "## " at the start of the line to pass clean version number to the next stage. 

## Step two - find git commit with given version in diff

`xargs -I LAST_VERSION git log --format="%H" --grep="LAST_VERSION"`

This is where xargs magic begins. We define a variable name `LAST_VERSION`, which will be replaced with the given value. I taught myself a mnemonic to remember `-I` as Instead.

xargs is due to receive the most recent version number found in pages/changelog.md and 

## Step three - print every commit between now and then 

`xargs -I COMMIT_HASH git log --format=%s%n%b COMMIT_HASH..HEAD`

Using the same trick as above to substitute hash of the commit with the most last logged version found in pages/changelog.md

`--format=%s%n%b` prints subject and body of every commit separated by a newline. 

## Result 

You will have the dump of git log since the version that was last mentioned in the changelog. You can add it to the changelog and tidy it up before committing the new changelog.


## Shoutouts

Brook Hong for developing such a great Chrome extension and later porting it to Firefox New Edition. 

Other contributors to Surfing Keys.

Douglas McIlroy - the creator of Unix pipes
