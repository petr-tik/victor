---
Title: "Grokking dfs and backtracking on a Graph (sort of)"
Date: "2017-04-12"
categories: hacking
draft: true
tags: [algorithms, graphs, dfs]
Author: Petr Tikilyaynen
description: "Implementing a recursive solution with backtracking"
---

## Problem statement

Given:
  * an array of ints (default - 6)
  * array of operations (default - addition, multiplication, division, deduction) 
  * a target int value.

Return True, if it's possible to combine all numbers in the array with operations to result in target value


## Brute force

Generate all combinations of operations (4**5 = 1024) and calculate them. If any one of them gives the target_value, return True. Otherwise, return False at the end.

## First attempt

```python
def f(arr, target, arr_index, results_so_far=None):
    if results_so_far == None:
        results_so_far = set()
        results_so_far.add(arr[5])
    if arr_index == -1:
        return any(target == x for x in results_so_far)
    s = set()
    for item in results_so_far:
        s.add(item + arr[arr_index])
        s.add(item * arr[arr_index])
        s.add(arr[arr_index] - item)
        if item != 0 and arr[arr_index] / item == int:
            s.add(arr[arr_index] / item)
    return f(arr, target, arr_index - 1, s)
```
