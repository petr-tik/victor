---
title: "Debugging hanging elpy on emacs"
date: "2017-04-06"
category: hacking
tags: 
 - emacs
 - python
 - strace
draft: false
author: Petr Tikilyaynen
description: Investigating a hanging emacs process
---

I was hacking on a small python script, minding my own business when emacs stopped reacting to my keyboard input. I could still switch windows and work with another applications, but emacs hang up on me. 

Having spent a couple of hours stracing, [grepping and awking emacs start-up syscalls]({filename}stracing_emacs_part_one.md), I was in the mood to debug some more. 

Attaching my shell to the pid of emacs (I usually only run 1 emacs instance, hence pgrep emacs). 

```bash
sudo strace -p $(pgrep emacs)
```
Returns the same error messages repeated.

```bash
pselect6(14, [7 13], [], NULL, {0, 19999519}, {NULL, 8}) = 0 (Timeout)
poll([{fd=7, events=POLLIN}], 1, 0)     = 0 (Timeout)
write(12, "{\"id\":91,\"method\":\"get_calltip\","..., 616) = -1 EAGAIN (Resource temporarily unavailable)
pselect6(14, [7 13], [], NULL, {0, 19999519}, {NULL, 8}) = 0 (Timeout)
poll([{fd=7, events=POLLIN}], 1, 0)     = 0 (Timeout)
write(12, "{\"id\":91,\"method\":\"get_calltip\","..., 616) = -1 EAGAIN (Resource temporarily unavailable)
```

Ad nauseum.

Using the combination of functional programming and bash magic, I nested one function call inside another to get the list of processes. `pgrep -P` returns the PIDs of all child processes of a given PID. 

```bash
$$$$ ps -o pid,pcpu,comm -p $(pgrep -P $(pgrep emacs))
  PID %CPU COMMAND
31513  97.4 python
```

There is only 1 child process, but it's eating up all the CPU time and killing my battery - it drained 13% in 10 minutes that I was googling and stracing. 

```bash
$$$$ kill $(pgrep -P $(pgrep emacs)
```

This made emacs responsive again, so I examined the emacs *Messages* buffer

```text
Wrote /home/petr_tik/Coding/misc/misc/dfs.py
error in process sentinel: elpy-rpc--default-error-callback: peculiar error: "terminated"
error in process sentinel: peculiar error: "terminated"
eldoc error: (file-error Writing to process bad file descriptor  *elpy-rpc [project:~/Coding/misc/misc/ python:/usr/bin/python]*)
```

[Here is a relevant GitHub issue](https://github.com/jorgenschaefer/elpy/issues/709)

Looks like it remains to be solved.
