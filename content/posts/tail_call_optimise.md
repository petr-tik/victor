---
Title: "Effect of language on hackerrank performance"
Date: "2016-10-27"
draft: true
categories: hacking
tags: [algorithms, hackerrank]
Author: Petr Tikilyaynen
description: "Investigating language effect on algorithm efficiency on HackerRank"
---


# Language effect on HackerRank solution performance

This article examines how the choice of language used in HackerRank tests might affect the pass/fail status of your solution. The same algorithmic puzzle is solved with python and JavaScript to highlight the  of different languages as a tool for quick algorithmic problems. This post is for candidates considering what language to do the problem in as well as hiring managers to assess how much language choice affects candidates' performance. 

## Tl;dr

  * Candidates: If your job application includes a HackerRank test, choose a language that has native support for concepts you will use in the puzzle (recursive functions need tail call optimisation). Choose the best tool for the job, even if the job is to implement a breadth-first search.

  * Hiring Managers: Check how many false negatives you had by rejecting solutions, where the language isn't efficient enough for the problem

## HackerRank

HackerRank is an online platform used to screen candidates applying for software developer positions. It presents the candidate with several puzzles (usually from the algorithms and data structures domains), a solved test case and a text editor to interactively try your solution in a chosen language. The solved testcase is usually simple enough for you can to work out the basic algorithm with pen and paper. Once you've ensured that your solution works on the test case, you submit it to an AWS-hosted environment, which compiles/interprets your program using the determined [environment](https://www.hackerrank.com/environment) to see if you get the right answer for previously unseen test cases. HackerRank measures the correctness and algorithmic complexity of your solution, which it estimates from your memory footprint and running time. There are 3 possible outcomes: pass, wrong answer and timeout. 

## Problem statement and solution

The solution uses a recursive function, which is exactly where JavaScript outperforms Python, due to ongoing work to optimise tail calling in the V8 engine. The python interpreter doesn't have tail call optimisation. 




[](http://www.2ality.com/2015/06/tail-call-optimization.html)

## Thanks






