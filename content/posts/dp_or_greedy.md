---
Title: "Difference between DP and greedy algorithms"
Date: "2017-04-20"
categories: hacking
draft: true
tags: [algorithms]
Author: Petr Tikilyaynen
description: "Can Dynamic Programming be greedy?"
---

The HackerRank puzzle to find a contiguous subarray with the maximum possible sum is in the Dynamic Programming section. The implemented solution feels more greedy to me than dynamic, so this is a collection of thoughts about naming algorithms


```python
def max_cont(arr, max_so_far=None, max_global=None):
    """
    Given an array and a starting value, 
    return the sum of the maximum contiguous array
    Solve dynamically
    [2, 6, -9]           returns 8
    [-3, -1, -5]         returns -1
    [2, -1, 2, 3, 4, -5] returns 10
    [6, -7, 2, 3, 4, -5] returns 9
    [6, -7, 2, 3, -5]    returns 6
    """
    if not arr:
        return max_global

    new_val = arr.pop(0)
    if max_so_far == None and max_global == None:
        max_so_far = new_val
        max_global = new_val
        return max_cont(arr, max_so_far, max_global)

    max_so_far = max(new_val, max_so_far + new_val)
    max_global = max(max_global, max_so_far)
    return max_cont(arr, max_so_far, max_global)
```


Dynamic programming is a technique of breaking a problem into subproblems and combining the solutions in each subproblem into a solution overall. Often dynamic programming problems have a recursive solution with a cache memoize answers to previously solved subproblems. 


In this case, when we consider a new element we have 2 choices - extend/grow the current subsequence or start a new subsequence from the current element. This is a greedy approach and requires no updating/reconsidering, if a new element is greater than the sum of current best subsequence with the new element, drop the baggage of the previous subsequence and start fresh. It might not be the best we've ever seen, hence the check to update max_global when appropriate. 

```max_so_far``` is the current subsequence
```max_global``` is the best so far. 

The greedy approach of selecting best subsequence fits the nicely to the recursive 
