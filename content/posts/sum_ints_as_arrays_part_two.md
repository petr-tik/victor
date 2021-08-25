---
title: "Comparing different ways to add ints II"
Date: "2017-07-16"
category: hacking
draft: false
tags: [python]
author: Petr Tikilyaynen
description: "Profiling Python"
---

## Background

As outlined in [part 1]({{< ref "sum_ints_as_arrays_part_one.md" >}}), we are comparing recursive and iterative implementations of long arithmetic of 2 arrays. As seen in the chart at the bottom of the post, there is a sudden jump in execution times of the recursive function, when the length of array becomes ~900 ints. Using the ```cProfile``` and ```line_profile``` modules in Python, this increase in execution times is investigated in this post. First cProfile was used to record and examine the execution times for `recur_sum` and `iter_sum`. After the bottlenecks were located, `line_profiler` was used to profile each function with higher granularity. To guarantee consistent analysis both implementations will be benchmarked with line profiling enabled. 

## Refactoring

The script from part 1 had to be changed to profile the relevant function calls and save the results. This effectively wraps the function calls with cProfiler and then saves the results into a .dmp type. Afterwards results are plotted.

### Plot results

Instead of using a scatter plot, normal plot was used, which made the increase in gradient more obvious. It also takes the right and left limits to the x values (lengths of the array). Setting xlim to the plot will help us focus the picture. We will not exceed recursion depth in this example. Hence we won't be marking the last point in recursive times.


```python
def plot_results_for_cprofile(xs, ys, r_limit, l_limit):
    plt.xlim(r_limit, l_limit)
    plt.xlabel('Size of input arrays')
    plt.ylabel('Time to calculate sum (ms)')
    plt.title('Comparing iterative vs recursive sum methods')

    iter_arr_lengths, recur_arr_lengths = xs
    iters, recurs = ys

    # plot iterative times
    plt.plot(np.array(iter_arr_lengths), np.array(iters), c="red")

    # plot recursive times
    plt.plot(np.array(recur_arr_lengths), np.array(recurs), c="green")

    fname = "plot_sum_ints.png"
    plt.savefig(fname, dpi=1200)
    print("Saved plot as {}".format(fname))
```


### Profile run

Profile run method instantiates 2 ```cProfile.Profile()``` classes for iterative and recursive solution profiling. Looping over different array lengths, the `iter_sum` and `recur_sum` solutions are profiled. The profiling information is saved to disk using the ```dump_stats()``` method, which takes a string for argument name. 


```python
def profile_run(r_limit, l_limit):
    import cProfile
    iter_arr_lengths = []
    recur_arr_lengths = []
    iter_times = []
    recur_times = []

    for arr_length in range(r_limit, l_limit, 1):
        arr1 = [9 for _ in range(arr_length)]
        arr2 = [1 for _ in range(arr_length)]

        pr = cProfile.Profile()
        pr2 = cProfile.Profile()

        pr.enable()
        res_iter, time_iter = iter_sum(arr1, arr2)
        pr.disable()
        pr.dump_stats("iter_{}".format(str(arr_length)))
        iter_arr_lengths.append(arr_length)
        iter_times.append(time_iter)

        pr2.enable()
        res_recur, time_recur = recur_sum(arr1, arr2)
        pr2.disable()
        pr2.dump_stats("recur_{}".format(str(arr_length)))
        recur_arr_lengths.append(arr_length)
        recur_times.append(time_recur)

    plot_results_for_cprofile([iter_arr_lengths, recur_arr_lengths],
                              [iter_times, recur_times], r_limit, l_limit)
```

### Dumping stats

Used the length of input arrays as id of this profiler run. Looking at the [source](https://github.com/python/cpython/blob/6f0eb93183519024cb360162bdd81b9faec97ba6/Lib/cProfile.py#L44-L48) for cProfile.Profile.dump_stats()

```python
    def dump_stats(self, file):
        import marshal
        with open(file, 'wb') as f:
            self.create_stats()
            marshal.dump(self.stats, f)
```

We see that it uses the marshal module. From the [documentation](https://docs.python.org/3/library/marshal.html), we know that:

> Details of the format are undocumented on purpose; it may change between Python versions (although it rarely does).

> This is not a general "persistence" module. For general persistence and transfer of Python objects through RPC calls, see the modules :mod:`pickle` and :mod:`shelve`. The :mod:`marshal` module exists mainly to support reading and writing the "pseudo-compiled" code for Python modules of :file:`.pyc` files. Therefore, the Python maintainers reserve the right to modify the marshal format in backward incompatible ways should the need arise. If you're serializing and de-serializing Python objects, use the :mod:`pickle` module instead -- the performance is comparable, version independence is guaranteed, and pickle supports a substantially wider range of objects than marshal.

> The :mod:`marshal` module is not intended to be secure against erroneous or maliciously constructed data. Never unmarshal data received from an untrusted or unauthenticated source.

What joy! `cProfile` (the builtin python profiler) uses a badly documented, backwards-incompatible, insecure module with incomplete support for Python types.

### Line profiling

Line profiling was implemented by changing the code for the `timeit` decorator function. This allowed repeat measurements to stay consistent between recursive and iterative methods. Assuming that the overhead of line profiling of the recursive and iterative solution is in the same order of magnitude, wrapping both ```recur_sum``` and ```iter_sum``` wasn't expected to change the difference between them too much. ```recur_sum_helper``` and ```iter_sum_helper``` had to be moved above ```timeit``` in the source code (reasons below). 

```python
def timeit(func):
    str_func_to_profile = func.__code__.co_names[0]
    func_to_prof = globals()[str_func_to_profile]

    def newfunc(*args, **kwargs):
        # locals() returns a dictionary, where 'args' is key for local vars
        # ASSUMPTION: both input arrays have the same length, use either
        arr_length = len(locals()['args'][0])
        # make a new instance of LineProfiler for each time iter_sum() is
        # called with new input arrays
        line_prof = LineProfiler()
        func_prof = line_prof(func)
        line_prof.add_function(func_to_prof)

        startTime = time.time()
        res = func_prof(*args, **kwargs)
        elapsedTime = time.time() - startTime
        line_prof.dump_stats("ll_{}_{}".format(
            str_func_to_profile, str(arr_length)))
        time_as_string = '{:.6f}'.format(elapsedTime * 1000)
        return (res, time_as_string)

    return newfunc
```

Below is a quick introduction to python decorators and how the timeit function had to change to include line profiling.

#### Decorators are evaluated at runtime

When a python module is loaded or runs, the wrappers are evaluated, as soon as they are encountered. Regardless if the wrapped function is even called anywhere in the module, the decorator processes and returns the new function, as soon as it is given a function to wrape. When the wrapped function is called, it has already been modified, so the function being executed is function that the decorator returned, when it was evaluated earler. To prove that decorators work at wrap-time, not call-time, set breakpoits ```pdb.set_trace()``` as below. 

```python
import pdb
pdb.set_trace() # breakpoint 1

@timeit
def iter_sum(arr1, arr2):
    r_arr1 = arr1[::-1]
    r_arr2 = arr2[::-1]
    return iter_sum_helper(r_arr1, r_arr2)[::-1]

pdb.set_trace() # breakpoint 2
```

When breakpoint 1 is hit, `iter_sum` hasn't been defined, so the Python interpreter throws a NameError. 

```bash
$$$$ python3 sum_ints_as_arrays.py 
> /home/petr_tik/Coding/misc/misc/sum_ints_profile/sum_ints_as_arrays.py(115)<module>()
-> @timeit
(Pdb) iter_sum.__name__
*** NameError: name 'iter_sum' is not defined
```

`(c)ontinuing` to breakpoint 2, now `iter_sum` has been defined and wrapped. ```newfunc``` is the name that  came from the closure of ```timeit```. This proves that `iter_sum` has already been wrapped by timeit, before it's first called.

```bash
(Pdb) c
> /home/petr_tik/Coding/misc/misc/sum_ints_profile/sum_ints_as_arrays.py(124)<module>()
-> @timeit
(Pdb) iter_sum.__name__
'newfunc'
```

#### Closures

Decorators in Python rely on the concept of closure. At the time when newfunc is defined inside the `timeit` function, there are 3 variables available to newfunc: str\_func\_to\_profile, func\_to\_prof and func (wrapped function) itself. Continuing the same pdb session, freevars inside the code object of `iter_sum` were examined.

```bash
(Pdb) iter_sum.__code__.co_freevars
('func', 'func_to_prof', 'str_func_to_profile')
```

#### Adding line-profiling to the decorator

Using the above and some [`inspect`](https://docs.python.org/3/library/inspect.html) hackery, we access the code object of func using  `__code__`. `co_names` returns a tuple of names of local variables. Both input funcs - `iter_sum` or `recur_sum` only have 1 local variable - its helper function. `iter_sum_helper` and `recur_sum_helper` are above this wrapper function in the source code. This guarantees that they will be found when `globals` is called inside the decorator. Using the string as the key, we retrieve the function object from the globals() dictionary. 

Originally, I made a mistake by instantiating the `LineProfiler` class inside `timeit`, but before `newfunc` is defined. This made the same instance of the `LineProfiler` object availabe to all calls of `iter_sum` or `recur_sum` respectively. This would append profiling results into the same file, which was later dumped under a new name. Profiling data for `recur_sum_919` included the profiling data for all previous runs, which made it incorrect. Instead, each time a function is called, a new instance of the `LineProfiler` is created, when the input func (`iter_sum` or `recur_sum`) is called. 

Overall running times are still collected and returned and they are expected to increase with the overhead of line profiling. The line profiler dumps stats into a file called by its function name and array length. The result and elapsed time are returned, used by `profile_run` to collect and plot time for each function call.

## Results

### Plot

![Photo]({attach}images/plot_sum_ints_profiler.png)

In the graph, green is still recursive, red is iterative times. There are several notables differences - times are higher overall - profiling has a noticeable overhead. The difference between iterative and recursive is still present and the shape of ups/downs is similar in both lines . There is a huge spike for the recursive solution when the input arrays are of size 907. This makes it easy to investigate function calls.

### Reading the cProfile dump

#### Read function

All instances of cProfile for each array length ```dump_stats``` into plaintext files recur_{arr_length} or iter_{arr_length}. ```read_dump.py``` is defined to print the dump to terminal to investigate, grep and read through it.

```python
import pstats
import sys


def main():
    if len(sys.argv) != 2:
        print("Supply a filename")
        return
    fname = sys.argv[1]

    stats = pstats.Stats(fname)
    stats.sort_stats("time").print_stats(1.0)

if __name__ == "__main__":
    main()
```

#### Results

Using this script, we examine the dumps of recursive calls with arrays of lengths 917 and 918 (before, during and after the peak).

```bash
$$$$ ./read_dump.py recur_917 | grep seconds
         5542 function calls (4625 primitive calls) in 0.011 seconds
$$$$ ./read_dump.py recur_918 | grep seconds
         5548 function calls (4630 primitive calls) in 0.039 seconds
$$$$ ./read_dump.py recur_919 | grep seconds
         5554 function calls (4635 primitive calls) in 0.011 seconds
```

At the peak, the number of function calls increases by 5, but the execution time more than triples.


```bash
petr_tik@merluza:~/Coding/misc/misc/sum_ints_profile$ ./read_dump.py recur_917 && ./read_dump.py recur_918 && ./read_dump.py recur_919
Sun Jul 23 19:18:39 2017    recur_917
         5542 function calls (4625 primitive calls) in 0.011 seconds
   ncalls  tottime  percall  cumtime  percall filename:lineno(function)
    918/1    0.010    0.000    0.011    0.011 sum_ints_as_arrays.py:52(recur_sum_helper)

Sun Jul 23 19:18:39 2017    recur_918
         5548 function calls (4630 primitive calls) in 0.039 seconds
   ncalls  tottime  percall  cumtime  percall filename:lineno(function)
    919/1    0.038    0.000    0.038    0.038 sum_ints_as_arrays.py:52(recur_sum_helper)

Sun Jul 23 19:18:39 2017    recur_919
         5554 function calls (4635 primitive calls) in 0.011 seconds
   ncalls  tottime  percall  cumtime  percall filename:lineno(function)
    920/1    0.010    0.000    0.011    0.011 sum_ints_as_arrays.py:52(recur_sum_helper)
```

In all three (and we can assume other) instances of `recur_sum`, nearly 100% of time is spent on recursive calls of `recur_sum_helper`. We will need to use line_profiling to get more detail about the increase in execution times. 

### Reading line profiling dump

#### Read function

The line_profiler module has separate function for loading stats and showing text of the stats object. For serialisation, the line profiler module uses the builtin pickle module, which has wider coverage and better support. 

```python
#! /usr/bin/env python3

import sys

from line_profiler import load_stats, show_text

def main():
    if len(sys.argv) != 2:
        print("Supply a filename")
        return
    fname = sys.argv[1]

    stats = load_stats(fname)
    show_text(stats.timings, stats.unit)

if __name__ == "__main__":
    main()
```

#### Results

```bash
$$$$ ./read_ll.py ll_recur_sum_helper_917
Timer unit: 1e-06 s

Total time: 0.006587 s
File: sum_ints_as_arrays.py
Function: recur_sum_helper at line 52

Line #      Hits         Time  Per Hit   % Time  Line Contents
==============================================================
    52                                           def recur_sum_helper(arr1, arr2, idx=0, res=[], carry=0):
    53       918          481      0.5      7.3      if not res:
    54         1            2      2.0      0.0          res = list()
    55       918          926      1.0     14.1      if idx >= len(arr1) and idx >= len(arr2):
    56         1            1      1.0      0.0          if carry == 1:
    57         1            1      1.0      0.0              res.append(1)
    58         1            1      1.0      0.0          return res
    59       917          797      0.9     12.1      if idx >= len(arr1):
    60                                                   carry, item_to_add = divmod(carry + arr2[idx], 10)
    61                                                   res.append(item_to_add)
    62                                                   idx += 1
    63                                                   return recur_sum_helper(arr1, arr2, idx, res, carry)
    64       917          782      0.9     11.9      if idx >= len(arr2):
    65                                                   carry, item_to_add = divmod(carry + arr1[idx], 10)
    66                                                   res.append(item_to_add)
    67                                                   idx += 1
    68                                                   return recur_sum_helper(arr1, arr2, idx, res, carry)
    69                                           
    70       917         1109      1.2     16.8      carry, item_to_add = divmod(carry + arr1[idx] + arr2[idx], 10)
    71       917          842      0.9     12.8      res.append(item_to_add)
    72       917          564      0.6      8.6      idx += 1
    73       917         1081      1.2     16.4      return recur_sum_helper(arr1, arr2, idx, res, carry)

Total time: 0.010676 s
File: sum_ints_as_arrays.py
Function: recur_sum at line 119

Line #      Hits         Time  Per Hit   % Time  Line Contents
==============================================================
   119                                           @timeit
   120                                           def recur_sum(arr1, arr2):
   121         1           11     11.0      0.1      r_arr1 = arr1[::-1]
   122         1            7      7.0      0.1      r_arr2 = arr2[::-1]
   123         1        10658  10658.0     99.8      return recur_sum_helper(r_arr1, r_arr2)[::-1]

$$$$ ./read_ll.py ll_recur_sum_helper_918
Timer unit: 1e-06 s

Total time: 0.034118 s
File: sum_ints_as_arrays.py
Function: recur_sum_helper at line 52

Line #      Hits         Time  Per Hit   % Time  Line Contents
==============================================================
    52                                           def recur_sum_helper(arr1, arr2, idx=0, res=[], carry=0):
    53       919          472      0.5      1.4      if not res:
    54         1            3      3.0      0.0          res = list()
    55       919          892      1.0      2.6      if idx >= len(arr1) and idx >= len(arr2):
    56         1            0      0.0      0.0          if carry == 1:
    57         1            1      1.0      0.0              res.append(1)
    58         1            1      1.0      0.0          return res
    59       918          763      0.8      2.2      if idx >= len(arr1):
    60                                                   carry, item_to_add = divmod(carry + arr2[idx], 10)
    61                                                   res.append(item_to_add)
    62                                                   idx += 1
    63                                                   return recur_sum_helper(arr1, arr2, idx, res, carry)
    64       918          776      0.8      2.3      if idx >= len(arr2):
    65                                                   carry, item_to_add = divmod(carry + arr1[idx], 10)
    66                                                   res.append(item_to_add)
    67                                                   idx += 1
    68                                                   return recur_sum_helper(arr1, arr2, idx, res, carry)
    69                                           
    70       918         1062      1.2      3.1      carry, item_to_add = divmod(carry + arr1[idx] + arr2[idx], 10)
    71       918          814      0.9      2.4      res.append(item_to_add)
    72       918          542      0.6      1.6      idx += 1
    73       918        28792     31.4     84.4      return recur_sum_helper(arr1, arr2, idx, res, carry)

Total time: 0.038265 s
File: sum_ints_as_arrays.py
Function: recur_sum at line 119

Line #      Hits         Time  Per Hit   % Time  Line Contents
==============================================================
   119                                           @timeit
   120                                           def recur_sum(arr1, arr2):
   121         1           11     11.0      0.0      r_arr1 = arr1[::-1]
   122         1            6      6.0      0.0      r_arr2 = arr2[::-1]
   123         1        38248  38248.0    100.0      return recur_sum_helper(r_arr1, r_arr2)[::-1]

$$$$ ./read_ll.py ll_recur_sum_helper_919
Timer unit: 1e-06 s

Total time: 0.006544 s
File: sum_ints_as_arrays.py
Function: recur_sum_helper at line 52

Line #      Hits         Time  Per Hit   % Time  Line Contents
==============================================================
    52                                           def recur_sum_helper(arr1, arr2, idx=0, res=[], carry=0):
    53       920          495      0.5      7.6      if not res:
    54         1            2      2.0      0.0          res = list()
    55       920          936      1.0     14.3      if idx >= len(arr1) and idx >= len(arr2):
    56         1            0      0.0      0.0          if carry == 1:
    57         1            1      1.0      0.0              res.append(1)
    58         1            0      0.0      0.0          return res
    59       919          788      0.9     12.0      if idx >= len(arr1):
    60                                                   carry, item_to_add = divmod(carry + arr2[idx], 10)
    61                                                   res.append(item_to_add)
    62                                                   idx += 1
    63                                                   return recur_sum_helper(arr1, arr2, idx, res, carry)
    64       919          785      0.9     12.0      if idx >= len(arr2):
    65                                                   carry, item_to_add = divmod(carry + arr1[idx], 10)
    66                                                   res.append(item_to_add)
    67                                                   idx += 1
    68                                                   return recur_sum_helper(arr1, arr2, idx, res, carry)
    69                                           
    70       919         1107      1.2     16.9      carry, item_to_add = divmod(carry + arr1[idx] + arr2[idx], 10)
    71       919          827      0.9     12.6      res.append(item_to_add)
    72       919          532      0.6      8.1      idx += 1
    73       919         1071      1.2     16.4      return recur_sum_helper(arr1, arr2, idx, res, carry)

Total time: 0.010754 s
File: sum_ints_as_arrays.py
Function: recur_sum at line 119

Line #      Hits         Time  Per Hit   % Time  Line Contents
==============================================================
   119                                           @timeit
   120                                           def recur_sum(arr1, arr2):
   121         1           11     11.0      0.1      r_arr1 = arr1[::-1]
   122         1            6      6.0      0.1      r_arr2 = arr2[::-1]
   123         1        10737  10737.0     99.8      return recur_sum_helper(r_arr1, r_arr2)[::-1]
```

## Conclusion

This post showed the use of `cProfile` and `line_profiler` modules implemented as wrappers to collect and review profiling information. Decorators, which rely on the concept of closures and runtime code inspection, were explained and used for implementing profiling. The spike in execution times of the recursive solution was found using line_profiling. Given arrays of length 918, the recursive sum function for some unexplained reasons takes 28x more time to run than previous and consequent function calls. 

## Future work

At this point, it's best to implement tracing either inside python interpreter or from outside the process. By tracing and logging each recursively created and executed stack frame inside `recur_sum_helper`, we can get more information about the slowdown. Another avenue for investigation can be looking into CPython source code. Methods like `list.append()` might cause reallocation, which would slow down the execution at some stack frames. The line profiling results suggest that would be unlikely, unless they fail to time that.
