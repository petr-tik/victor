---
title: "Unexpected breadth-first search"
date: "2017-02-27"
category: hacking
draft: false
tags: 
 - python
 - algorithms
 - hackerrank
author: Petr Tikilyaynen
description: "Uncovering a graph theory problem"
---

This [puzzle](https://www.hackerrank.com/challenges/candies) is in the dynamic programming section of HackerRank. Dynamic Programming problems are often solved recursively. This is a story of ignoring all the obvious clues and finding another type of solution.

To speed up recursion, you should find a way to memoize/cache results of previous calculations. 

## Problem statement:
    
    Given an array of students' grades (ints) in the same order as they sit. 
    Return the minimal number of candies all students receive, such that:
    
    * out of 2 adjacent students, the one with a higher grade receives more candy
    * each student receives at least 1 piece of candy
  

### Plot twist

Alternatively, you can look at the problem as a graph theory problem. 

Represent each student as a node on a plane. Among adjacent nodes, draw directed edges from the node with a lower grade to the node with a higher grade. All the nodes without incoming edges aren't greater than their neighbours (equal grades means you can give less candy), so they will receive the minimum amount - 1. Now start several breadth-first searches from each of the nodes without incoming edges (they will be the local start points). Visit node and increment the value at its index in the candies array. Differently to normal breadth-first search, you don't need to keep track of previously visited nodes and you can revisit them to increment the counter. In case you have a peak around a point 8 (index = 3) eg

grades
1 2 4 8 6 5 3 2 1

candies (illegal) - if you don't revisit nodes to update counter. 
1 2 3 4 5 4 3 2 1 

candies (solution)
1 2 3 6 5 4 3 2 1


### Complexity

The prepare\_for_bfs method takes linear O(n) time and bfs takes maximum O(V + E)


The code is [here](https://github.com/petr-tik/misc/blob/master/candies.py)

If you see a problem in description or the code, please open issues, send PRs
