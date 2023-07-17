---
title: "Notes on python's GC"
date: "2017-03-07"
categories: hacking
draft: false
tags: 
 - python
 - gc
 - memory
author: Petr Tikilyaynen
description: "Notes from different videos/texts"
---

Notes on [Memory Management in Python - YouTube](https://www.youtube.com/watch?v=arxWaw-E8QQ)

GC is a mechanism for managing memory at runtime. There are several methods including: mark-and-sweep and reference counting. Different language runtimes use different GC mechanisms, each asking for tradeoffs. eg. Java uses mark-and-sweep, which runs less frequently, but the sweep stage 'stops the world' and tidies up. I will be discussing CPython implementation and call it python for brevity (saving a character is very important). There are JPython and IronPython, which rely on JVM and CLR GC mechanisms respectively.


## Mechanism

CPython uses reference counting with an optimisation to eliminate cyclic references, hence slower runtime. Similarly to pointers in C, the variable name is created on the stack and the pointer on the heap. Each created object has a field for storing its reference count - the number of variables that refer to the object. As soon as the refcount falls to 0, the GC collects/tidies up the object.

Doing simple reference counting is prone to not deleting cyclically referenced objects. eg. If Object A refers to Object B and Object B to Object A, they will never get collected using simple reference counting (both will always have a ref count of at least 1). 

### Difference between py2 and py3 gc. 

Python3 has a get_stats() method, which returns a list of dictionaries containing per-generation statistics. 

### Interacting

THere is a builtin module called gc, which allows you to enable, disable or run GC at any point in your programme. Some explanations that I read say you can change the number of generations, yet I can't find a method for that. The gc.set_threshold() command throws a "TypeError:  takes at most 3 arguments (4 given)". 



## Optimisations/heuristics

### Generations

All objects are split into 3 exclusive generations. The idea behind it is that objects won't live long, so younger generations are GC'ed more often than older generations. Generation 0 is where the newly created object lives, until it's spent enough time to be promoted. 


### Global value reuse

When a new variable (reference) is created, the python runtime checks if an object with such a value already exists. If it does, the new variable doesn't create a reference, instead it increases the refcount of int_object with value 10 to 2 as below. This works either when the object a new object is created or a primitive object's value is changed to match the value of an already existing object.

```python

>>> x = 10
>>> y = 10
>>> x is y
True
>>> id(x) == id(y)
True
>>> z = 9
>>> id(z) == id(y)
False
>>> z += 1
>>> id(z) == id(y)
True
```

Python creates an int object on the heap. If a new variable is created on the stack and assigned to a value, python sets up a reference between the new variable and the already existing object. 
