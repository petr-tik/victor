---
title: "Comparing different ways to add ints I"
date: 2017-06-27
categories: hacking
draft: false
tags: [algorithms, hackerrank, python]
author: Petr Tikilyaynen
description: "Exploring the tradeoffs between recursive and iterative solutions"
---

## Puzzle

Given 2 ints represented as array of digits in order (eg. 843 = [8, 4, 3]), implement a function that returns a sum of the 2 ints in the same format.

eg. 

[8, 4, 3] + [1, 8, 2] = [1, 0, 2, 5]


## Idea 

Implement and profile recursive and iterative solutions to the puzzle above.


### Recursive solution

```python
def recur_sum_helper(arr1, arr2, idx=0, res=[], carry=0):
    if not res:
        res = list() # guarantee it doesn't change array outside func scope
    if idx >= len(arr1) and idx >= len(arr2):
        if carry == 1:
            res.append(1)
        return res
    if idx >= len(arr1):
        carry, item_to_add = divmod(carry + arr2[idx], 10)
        res.append(item_to_add)
        idx += 1
        return recur_sum_helper(arr1, arr2, idx, res, carry)
    if idx >= len(arr2):
        carry, item_to_add = divmod(carry + arr1[idx], 10)
        res.append(item_to_add)
        idx += 1
        return recur_sum_helper(arr1, arr2, idx, res, carry)

    carry, item_to_add = divmod(carry + arr1[idx] + arr2[idx], 10)
    res.append(item_to_add)
    idx += 1
    return recur_sum_helper(arr1, arr2, idx, res, carry)
```

Having done some Clojure, functional tools like map and reduce made it feel that a recursive solution was going to be concise. Handling the same edge cases across different array lengths made the implementation more heavily branched and less pretty than expected.

The final return statement will activate once idx exhausts both arrays (i.e. incremented beyond both lengths). If the carry bit has been carried over from the previous stack frame, which called this last stack frame, add 1 to the end of the array and return the result. 

Otherwise, if either of the arrays is exhausted, add the ints from the other array keeping carry bit in mind. All 3 cases (arr1 - exhausted, arr2 - not; arr2 - exhaused, arr1 - not; arr1 and arr2 still not exhausted) use divmod function to set the carry bit and item\_to\_add. On Intel CPUs this should happen in 1 instruction. The only difference is using both arrays if both are still not exhausted.


### Iterative solution

Unrolls the recursive loop. Instead of creating a stack frame for each digit, add as many digits as possible before one of the arrays runs out, then handle the leftover digits from the longer array. In the case of arrays/numbers of the same length, there won't be any branch misprediction and we will fall through down to the return statement.


```python
def iter_sum_helper(arr1, arr2):
    idx = 0
    carry = 0
    res = []
    while idx < min(len(arr1), len(arr2)):
        carry, item_to_add = divmod(carry + arr1[idx] + arr2[idx], 10)
        res.append(item_to_add)
        idx += 1
    if len(arr1) > len(arr2):
        while idx < len(arr1):
            carry, item_to_add = divmod(carry + arr1[idx], 10)
            res.append(item_to_add)
            idx += 1
    else:
        while idx < len(arr2):
            carry, item_to_add = divmod(carry + arr2[idx], 10)
            res.append(item_to_add)
            idx += 1
    if carry == 1:
        res.append(1)
    return res
```

### Wrapper to time each function call

```python
def timeit(func):
    def newfunc(*args, **kwargs):
        startTime = time.time()
        res = func(*args, **kwargs)
        elapsedTime = time.time() - startTime
        time_as_string = '{:.6f}'.format(elapsedTime * 1000)
        return (res, time_as_string)
    return newfunc
```

This takes the wrapped function, passes the original args, times how long it took to execute and returns a tuple of function return value and time\_as\_string.


```python
@timeit
def iter_sum(arr1, arr2):
```

For a fair comparison, both should have the same design and stack allocation strategy. Hence both iter\_sum and recur\_sum methods reverse the incoming arrays and return the result of the helper. The iterative method calculates everything in 1 stack frame. The recursive recur\_sum\_helper (by definition) creates a stack frame for each call. 

As both \_sum methods prepare and pass reversed arrays into helper methods, the helper methods return the result array in the opposite order. Both \_sum methods reverse the return arrays before returning.

#### Bug

In the first version of the recur\_sum\_helper and wrapper there was a bug - the recursive solution returned an array much longer than expected. This was the wrapper's fault, as was proven by running the methods without wrapping and stepping through it with pdb. 

The timeit wrapper method tooks the args and kwargs of the wrappee and kept them across runs. From the second interation onwards, the res array in the wrapped recur\_sum\_helper was kept inside the wrapper. Python variables are references, so after the res variable was created inside the scope of the wrapper, following ```res.append``` calls grew the same res array as before. 

Adding

```python
def recur_sum_helper(arr1, arr2, idx=0, res=[], carry=0):
    if not res:
        res = list()
```

solved the problem by creating a new array.


## Performance comparison

Using the script below, the wrapper described above, recursive and iterative solutions were benchmarked. The plots below show show time on the y-axis against the size of 2 input arrays on the x-axis. Green points - recursive times, red - iterative, blue star is the stack length of the array at which stack overflows. Catching stack overflow at runtime has to be done with a try/except loop, which breaks on RuntimeError. 

```python
def try_different_lengths_before_breaks(r_limit, l_limit, py_stack_limit=None):
    if py_stack_limit:
        sys.setrecursionlimit(py_stack_limit)
    iter_arr_lengths = []
    recur_arr_lengths = []
    iter_times = []
    recur_times = []

    for arr_length in range(r_limit, l_limit, 1):
        arr1 = [9 for _ in range(arr_length)]
        arr2 = [1 for _ in range(arr_length)]
        # good test case, because there will be a carry bit over every step
        res_iter, time_iter = iter_sum(arr1, arr2)
        iter_arr_lengths.append(arr_length)
        iter_times.append(time_iter)
        try:
            res_recur, time_recur = recur_sum(arr1, arr2)
            recur_arr_lengths.append(arr_length)
            recur_times.append(time_recur)
            if res_recur != res_iter:
                print("ERROR - {} != {}".format(res_recur, res_iter))
                break
        except RuntimeError:
            # stack limit exceeded
            break
    return iter_arr_lengths, iter_times, recur_arr_lengths, recur_times


def plot_results(xs, ys):
    plt.axis([0, 1005, 0, 1.2])
    plt.xlabel('Size of input arrays')
    plt.ylabel('Time to calculate sum (ms)')
    plt.title('Comparing iterative vs recursive sum methods')

    iter_arr_lengths, recur_arr_lengths = xs
    iters, recurs = ys
    point_normal = 5
    point_stack_over = 300

    # plot iterative times
    plt.scatter(np.array(iter_arr_lengths), np.array(iters),
                s=point_normal, color="red", marker=".")

    # plot recursive times
    plt.scatter(np.array(recur_arr_lengths)[:-1], np.array(recurs)[:-1],
                s=point_normal, color="green", marker=".")
    # last point in recursive times is before stack overflow
    plt.scatter(np.array(recur_arr_lengths)[-1], np.array(recurs)[-1],
                s=point_stack_over, color="blue", marker="*")

    fname = "sum_ints_plot.png"
    plt.savefig(fname, dpi=1200)
    print("Saved plot as {}".format(fname))
```


### Stack depth limits

The first discovery was the limit to stack depth (it grows downards, contrary to common sense of adding things to the top of the stack). The default value is 1000 in Python 3.4 (use `sys.getrecursionlimit()` to look it up). Considering that recur\_sum\_helper is called inside recur\_sum, which is wrapped and called inside \_\_main\_\_, we only have 996 stack frames for the recursive sum. 

```python
$$$ python3
Python 3.4.3+ (default, Oct 14 2015, 16:03:50) 
[GCC 5.2.1 20151010] on linux
Type "help", "copyright", "credits" or "license" for more information.
>>> import sys
>>> sys.getrecursionlimit()
1000
```

### Plots

![Photo]({attach}images/plot_sum_ints_stack_standard.png)

The blue star marks a point of max_stack_depth. Generally, both scatter plots show linear increase in time with a sudden jump in recursive at ~900 

![Photo]({attach}images/plot_sum_ints_stack_extra.png)

Using the same sys module, I could setrecursionlimit to a higher than default value and explore the difference between recursive and iterative solution on bigger input arrays. As expected, iterative kept winning and recursive suffered another drastic jump in times (~1600), thought the gradient remained linear.


## Conclusion

In this post, a simple problem was solved recursively and iteratively. Afterwards, both solutions were benchmarked and analysed in terms of their scalability. 

A recursive solution appears to purists and can be more readable in some cases like tree traversal. In this case, the recursive solution suffered. When combined with the lack of TCO and a relatively low default recursion depth limit value in the CPython interpreter, it proved unscalable and less efficient than iterative. Additionally, wrapping a recusive function introduced a bug, which was absent from the iterative solution.
