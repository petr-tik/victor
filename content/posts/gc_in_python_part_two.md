---
title: "Diving into CPython GC module"
date: "2017-08-05"
category: hacking
draft: false
tags: [python, gc, memory]
description: "Reading source code for gcmodule.c"
---

This is a deep dive into the source code for `Modules/gcmodule.c` inspired by my previous [article]({{< ref "gc_in_python.md" >}}), which gave a high-level overview of the GC mechanism in CPython. I am doing my best in reading the source, documentation and commit messages to outline my understanding of the internals. If you see an error, missing information or a typo, please [open an issue](https://github.com/petr-tik/petr-tik.github.io/issues)

# Why does Python need garbage collection?
 
As a managed memory runtime, CPython doesn’t give the programmer direct memory control. This makes it easier to write code without worrying about allocating memory for your data. Garbage collection is a mechanism for regularly checking that pre-allocated memory is still in use. Being in use means other objects still refer to you for something and your reference count is above 0. Once an object isn't in use, the memory allocated for it is collected and becomes available to future allocations.
 
# What kind of GC does Python use?

Python uses a generation-based ref-counting GC. The number of generations is defined in a macro as 3, where 0th generation keeps track of most recently allocated objects, 2nd generation of long lived objects. Every `gc_generation` has a threshold (number of objects after which a collection is performed) as defined below (taken from gcmodule.c).


```c
struct gc_generation {
    PyGC_Head head;
    int threshold; /* collection threshold */
    int count; /* count of allocations or collections of younger
                  generations */
};

#define NUM_GENERATIONS 3
#define GEN_HEAD(n) (&generations[n].head)

/* linked lists of container objects */
static struct gc_generation generations[NUM_GENERATIONS] = {
    /* PyGC_Head,                               threshold,      count */
    {{{GEN_HEAD(0), GEN_HEAD(0), 0}},           700,            0},
    {{{GEN_HEAD(1), GEN_HEAD(1), 0}},           10,             0},
    {{{GEN_HEAD(2), GEN_HEAD(2), 0}},           10,             0},
};
```

## What are the thresholds?
 
The thresholds are initiated at 700, 10 and 10 respectively. This means GC will be kicked off for 0th generation, when we allocate 700th object or promote 10 objects to either 1st or 2nd generation. The first generation can only have 10 objects (objects that survive collection move to a higher generation). The second generation is the oldest, so objects that survive collection move nowhere and stay in the second generation. The difference between 700 and 10 relies on the heuristic that few objects will survive after 1 generation. This optimises the effect of GC on runtime performance working with newly allocated objects. To improve the performance wrt to long-living objects another heuristic is used to avoid collecting the oldest generation, which can have an unlimited number of objects.


# How is GC invoked?

## By the interpreter
 
Most of the time, the call to start a GC cycle is done as a result of allocating a new object. After a new object has been allocated, `_PyObject_GC_Alloc` checks if it exceeds the threshold for 0th generation and calls `collect_generations`.

```c
static PyObject *
_PyObject_GC_Alloc(int use_calloc, size_t basicsize)
{
    PyObject *op;
    PyGC_Head *g;
    [...]
    size_t size = sizeof(PyGC_Head) + basicsize;
    if (use_calloc)
        g = (PyGC_Head *)PyObject_Calloc(1, size);
    [...]
    _PyGCHead_SET_REFS(g, GC_UNTRACKED);
    generations[0].count++; /* number of allocated GC objects */
    if (generations[0].count > generations[0].threshold &&
        enabled &&
        generations[0].threshold &&
        !collecting &&
        !PyErr_Occurred()) {
        collecting = 1;
        collect_generations();
        collecting = 0;
    }
    op = FROM_GC(g);
    return op;
}
```

The `collect_generations` method finds the oldest generation with more objects than the threshold allows and collects everything up to that generation. `collect_generations` calls `collect_with_callbacks`, which calls `collect` for the given generation.

This method is used by `_PyObject_GC_Calloc` and `_PyObject_GC_Malloc`, which are called by `PyObject_GC_New` - the standard way to allocate new list, dictionary, class, iterator, set, slice and many other built-in Python types.


## By the user/programmer

Users can directly call `gc.collect` to run a full collection. `gc.collect`, its C equivalent - `PyGC_Collect` and `collect_generations`, which uses pre-registered callbacks and executes them before and after the gc has been called. 

# collect method

However you invoke the GC, it all comes down to the `collect` method, which takes the generation number for which the collection is performed and starts the GC cycle. Below is the main collect method found in [Modules/gcmodule.c](https://github.com/python/cpython/blob/3.6/Modules/gcmodule.c#L899-L1081).


# How do you prepare a generation for collection?

To prepare a genertion for collection, we merge all younger generations into the generation that is currently being collected. `gc_list_merge` appends the younger generation to the list of the currently collected generation.

## gc\_list\_merge

```
/* append list `from` onto list `to`; `from` becomes an empty list */
static void
gc_list_merge(PyGC_Head *from, PyGC_Head *to)
{
    PyGC_Head *tail;
    assert(from != to);
    if (!gc_list_is_empty(from)) {
        tail = to->gc.gc_prev;
        tail->gc.gc_next = from->gc.gc_next;
        tail->gc.gc_next->gc.gc_prev = tail;
        to->gc.gc_prev = from->gc.gc_prev;
        to->gc.gc_prev->gc.gc_next = to;
    }
    gc_list_init(from);
}
```

By creating a variable for `tail`, we can save the pointer to the last node in the `to` list. First, we link the second node in the from list with the end of the to list using the `tail` variable. The second node in the `from` list becomes the head of the merged list. At the end, we make the head node of the `to` list point its prev pointer to the last node of the `from` list and the next pointer of the last node of the `from` list to the first node of the `to` list. 

`gc_list_init` makes the sentinel node points both pointers to itself. The first node in any gc list is therefore always a sentinel node. 

Therefore we merge the `from` list to the left of the `to` list. In a full collection, the 0th generation is merged with the 2nd first. The result, where the nodes from the 0th collection are to the left of the nodes from the 2nd collection, is merged with the 1st generation. This results in the following order:

1st generation -> 0th generation -> 2nd generation

## After merging

Having defined young earlier (currently collected generation) and old (generation right of current) now assign values to them. `young` acquires the value of the gc_list, which now contains the result of merging all previous generations with the current. `old` is set to the head of generation to the right, if it exists. eg. when generation = 2, old = young. 

`update_refs` and then `substract_refs` prepares the young generation of collection. At the start of a collection, `update_refs` copies the true refcount to `gc.gc_refs`, for each object in the generation being collected. `update_refs` copies refcnt value from PyObject’s objcnt to gc’s gc_refs field. This field is set to different statuses to signal, if the object is still attached to any other objects. 

`subtract_refs` then adjusts `gc_refs` so that it equals to the number of times an object is referenced directly from outside the generation being collected. This deals with cycle-detection. Whenever another object starts using PyObject op, Py\_INCREF is called on this object. Py\_INCREF increments the number of total references that have been given out and the objcnt of the given object.

## What happens in a collection?

### Tentatively move unreachable objects

After all the objects are merged into the `young` generation list, another list is initiated to keep track of unreachable objects. `move_unreachable` walks across the `young` list, where objects have had their `ob_refcnt` and `gc_refs` updated. Those with refcount <= 0 are moved into unreachable list and its `gc_refs` is set to `GC_TENTATIVELY_UNREACHABLE`. Being moved into the unreachable list at this point is no guarantee of being garbage collected, as these objects will be assessed again. The objects that remain in the `young` list are guaranteed to avoid collection and are promoted to the `old` generation.

### Promote survived objects to the older generation

The objects in young that haven't been marked as `GC_TENTATIVELY_UNREACHABLE` are definitely getting promoted to the next generation by merging `young` with `old`. Now, `young` contains the sentinel node, `old` all the objects that survived this collection and `unreachable` objects that may or may not be collected.

### Deal with finalizers

At this point, the objects in `unreachable` are potentially reachable. Those with finalizers might still be reachable. If so, we can recover them.

`move_legacy_finalizers` moves the objects in `unreachable` with `tp_del` slots into `finalizers`. Objects moved into `finalizers` have `gc_refs` set to `GC_REACHABLE`; the objects remaining in `unreachable` are left at `GC_TENTATIVELY_UNREACHABLE`. Even now, the objects in `unreachable` are potentially alive. 

`move_legacy_finalizers(PyGC_Head *unreachable, PyGC_Head *finalizers)` moves objects that are reachable from `finalizers`, from the `unreachable` set into `finalizers` set.

### clear weakrefs

#### What are weak references?

Weak references are used to track objects that shouldn't be uncollectable only when tracked. Caching or mapping keys to large objects has a large memory footprint. Creating a reference between many large objects and their descriptions (like keys in a dictionary) would make them uncollectable, until the dictionary/cache becomes unreachable. Creating a weak reference, however, doesn't contribute to the `gc_refs` count, so when the object has no real references outside its cache/container, it can be collected. Tidies up all objects in `unreachable` and guarantees that none of them have weakrefs to other objects.

#### How are they tidied up?

`handle_weakrefs` iterates over the objects in `unreachable`, registering callbacks from each weakref. If the callback revives the object, we promote it to the `old` generation.


### check and revive garbage if necessary

`finalise_garbage` calls objects' custom destructors on the objects currently deemed unreachable. Calling a finalizer might reset `gc_refs` back to `GC_REACHABLE`. 

`check_garbage` also uses `substract_refs` to confirm there are no references to the objects in `unreachable` from outside the set. If there is at least one, it means the whole cycle is accessible from the outside, so `revive_garbage` makes every object in `unreachable` `GC_REACHABLE` again and merges the whole list with `old` generation.


### delete garbage


Even if an object finds itself in the `unreachable` list at this stage, it is not doomed! There is still hope, all the way up until garbage is deleted. 

`delete_garbage` traverses through the `unreachable` list and if it has a `tp_clear` method, invokes it. If the object is still alive after that, its `gc_refs` is set to GC_REACHABLE and it's moved to the `old` generation. 

The big life lesson is: if you are a python object and no one is reaching out to you, you have legacy finalizers, and you have no weak references - don't despair. If your `tp_clear` method changes your `gc_refs` you might come back to life and get promoted to older generation.

### clear freelists

If it's a full collection, freelists for different data structures are cleared. More detail below.

# What is the difference between a full and a normal collection?
 
## Full collection runs less frequently using a heuristic

The first 2 generations are bounded by thresholds, whereas generation 2 can grow without a limit. Collecting all generations (called full collection) including the 2nd every time, would lead to quadratic running time. We can either skip objects or perform fewer collections to help our runtime. A heuristic is used to run fewer collections by calculating a ratio of objects that survived a full collection over those that that are yet to go through a full collection. When the ratio is greater than 4, we perform a full collection.

```c
static Py_ssize_t
collect_generations(void)
{
    ...
    for (i = NUM_GENERATIONS-1; i >= 0; i--) {
        if (generations[i].count > generations[i].threshold) {
    ...
        if (i == NUM_GENERATIONS - 1
                && long_lived_pending < long_lived_total / 4)
                continue;
            n = collect_with_callback(i);
```

We invoke a full collection if more than 25% of the objects have been allocated since the last full collection.

## Dictionaries are untracked

### What kind of objects are tracked?

Python has a mix of immutable and mutable data structures. If an immutable object has many references to it, none of them can change it, so there is no need to track the references. Tuples and strings are strictly immutable in python. Every modification of an existing tuple/string, allocates a new object of the same type, applies the transformation in-memory and copies the result into the newly allocated object. Tuples are slightly different from strings, because they are container objects i.e. they keep track of other objects inside. An immutable container like tuple may contain a mutable object like a list, which needs GC. A completely immutable container - tuple of integers/strings will neither change as a container nor as its members. Therefore there is no need to GC track it. 

### Why and how do you track/untrack objects?
 
 By default, we still track newly created tuples and leave it to the GC to untrack them. `move_unreachable` uses `_PyTuple_MaybeUntrack` (defined in [Objects/tupleobject.c](https://github.com/python/cpython/blob/3.6/Objects/tupleobject.c#L180-L203)), which iterates over all the objects in the tuple. If there are no NULL elements (yet to be constructed), it untracks the tuple object i.e. sets its `gc_refs` to `_PyGC_REFS_UNTRACKED` and removes its PyGC_Head object from its generation list.

Dictionaries containing only immutable objects like strings also don’t need tracking. In a full collection, we examine which dictionaries we can untrack and untrack them if the keys and values in the dictionary don't need tracking. 

### Protip

To optimise memory usage: 

  * Use tuples for data and `__slots__` for your classes
  * If using dictionaries: use immutable objects (ints, strings; NOT lists) as keys and values. 
  * If you really care about memory, write a C module that you can load into your CPython


## Surviving objects don't get promoted

There is no older generation to get promoted to. When `young != old`, the objects that are still reachable in the `young` list are moved to `old`. Collecting the oldest generation means we cannot move/promote surviving objects any further.

```
    else {
        /* We only untrack dicts in full collections, to avoid quadratic
           dict build-up. See issue #14775. */
        untrack_dicts(young);
        long_lived_pending = 0;
        long_lived_total = gc_list_size(young);
    }
```

We don't move anything anywhere, just reset `long_lived_pending` (no object has not survived a full collection) and update `long_lived_total` with the number of objects. 
 
## Clearing freelists

As mentioned above, freelists are cleared during full collection.

### What are freelists?

Free lists are lists of primitive Python object types allocated during CPython interpreter start. Preallocating basic object types like ints, lists, dictionaries and sets helps users avoid calling `malloc` for the first X object creations. Similarly, when an object is collected, it's just returned to the freelist of that PyObject type instead of calling `free`. Both `malloc` and `free` are syscalls, hence require a context switch and unnecessarily increase latency. Only if your programme uses more objects than originally allocated, will you call malloc. Example freelist from `dictobject.c` below

The CPython interpreter allocates a list of 80 dictionary objects.

```c
#ifndef PyDict_MAXFREELIST
#define PyDict_MAXFREELIST 80
#endif
static PyDictObject *free_list[PyDict_MAXFREELIST];
static int numfree = 0;
```

### Why does CPython preallocate 80 dictionaries?

The commit adding free_lists and their sizes is an old svn commit with more than a dozen of features in one without explanation for any of the values. Some make more sense - powers of 2 like 1024, 4096, but 80 is somewhat confusing. Given that the size of a dictionary is 400 bytes, 80 dictionaries is 32000 bytes, which might be friendlier to memory.

### How is freelist used to alloc/free dictionaries?

In the function that creates a new dictionary from given keys and values, we first check if we can use a pre-allocated dictionary from the freelist. If all dictionaries in the freelist have been used already (numfree >= 80), we have to allocate our own. Otherwise, Using numfree as index into the array of preallocated data types (eg. dictionaries), we assign mp to a dictionary from the list. Interestingly enough, `if (numfree)` will also execute the branch, if numfree is negative, which is semantically incorrect, but not impossible.


```c
static void
new_dict(PyDictKeysObject *keys, PyObject **values)
{
    PyDictObject *mp;
    assert(keys != NULL);
    if (numfree) {
        mp = free_list[--numfree];
    ...
    return (PyObject *)mp;
}
```

To deallocate we return the dictionary to the freelist, if we still haven't used up the whole list. If we haven't allocated all dictionaries from the freelist, it means, we can return the current dictionary to the list.

```c
static void
dict_dealloc(PyDictObject *mp)
{
    ...
    if (numfree < PyDict_MAXFREELIST && Py_TYPE(mp) == &PyDict_Type)
        free_list[numfree++] = mp;
```

### How are freelists cleared?

Each of the listed types in their `Objects/dictobject.c` source files have a method for clearing its freelist. Curiously, the `PyDict_ClearList` method returns the number of freed objects, but all invocations of the method cast the return type to void, making you wonder, why it returns anything in the first place.

```c
int
PyDict_ClearFreeList(void)
{
    PyDictObject *op;
    int ret = numfree + numfreekeys;
    while (numfree) {
        op = free_list[--numfree];
        assert(PyDict_CheckExact(op));
        PyObject_GC_Del(op);
    }
    while (numfreekeys) {
        PyObject_FREE(keys_free_list[--numfreekeys]);
    }
    return ret;
}
```

Iterates over the freelist, GC_deleting each object in the list. In the end, we have numfree set to 0 and a freelist full of objects ready to be used again.

## What does the collect method return?

Returns a static signed size\_t int. Input is generation (between 0 and 2 - higher is older), pointer to a variable tracking the `n\_collected` objects so far, `uncollectable` and `nofail` variable. Looking ahead `nofail` is only used once to decide if an error message should be printed to terminal. Both Py\_ssize\_t objects - `n\_collected` and `n\_uncollectable` - will be updated in-place (at their addresses) with m and n respectively.

```c
    int i;
    Py_ssize_t m = 0; /* # objects collected */
    Py_ssize_t n = 0; /* # unreachable objects that couldn't be collected */
```

## Why are variables like m and n used?

I guess programmers in the 90s/early 00s were paid inversely proportionally to the number of chars they typed. That would explain `mkdir`, `creat`, `m`, `n`. Apart from that the gcmodule is a joy to read through - well commented, with descriptive commit messages and a separate .rst doc file.


# What is PyGC_Head and how is it related to PyObject?

### PyGC_Head

Most variables are of type PyGC_Head, whose definition is in [objimpl.h](https://github.com/python/cpython/tree/3.6/Include/objimpl.h#L251-L259)

```c
/* GC information is stored BEFORE the object structure. */
#ifndef Py_LIMITED_API
typedef union _gc_head {
    struct {
        union _gc_head *gc_next;
        union _gc_head *gc_prev;
        Py_ssize_t gc_refs;
    } gc;
    double dummy;  /* force worst-case alignment */
} PyGC_Head;
```

The meaty part of the type is pointers of the same type to next and previous `_gc_head` types and the `gc_refs` that keeps track of the number of references.

### Why double dummy? 

Paraphrasing the commit message - the `double dummy` is to make sure 8-byte alignment won't break. When 8-byte alignment is required, padding is added, otherwise, there won't be any change.

### Why recursively defined gc struct?

This uses a sentinel doubly linked list. An empty linked list contains one node, whose `.gc_prev` and `.gc_next` link to the node itself. Appending nodes to the end of a list means linking the `.gc_next` and `.gc_prev` of the new_node to the head of the list and last element of the list respectively. The first element is a dummy - sentinel - node.  That's why all list traversal operations begin initiate `gc = list->gc.gc_next` as below

```c
static Py_ssize_t
gc_list_size(PyGC_Head *list)
{
    PyGC_Head *gc;
    for (gc = list->gc.gc_next; gc != list; gc = gc->gc.gc_next) {
        n++;
```

and to check emptiness you need to compare pointers between the head and the first next element after the sentinel. 

```c
static int
gc_list_is_empty(PyGC_Head *list)
{
    return (list->gc.gc_next == list);
}
```

## PyObject

The PyObject struct is defined in [Include/object.h](https://github.com/python/cpython/blob/3.6/Include/object.h). Contains the reference count and type of the object.

```c
/* Define pointers to support a doubly-linked list of all live heap objects. */
#define _PyObject_HEAD_EXTRA            \
    struct _object *_ob_next;           \
    struct _object *_ob_prev;

typedef struct _object {
    _PyObject_HEAD_EXTRA
    Py_ssize_t ob_refcnt;
    struct _typeobject *ob_type;
} PyObject;
```


## PyObject to/from PyGC_Head

There are helper method defined as macros to convert between `PyObject` and `PyGC_Head`, to read/write reference counts from one to the other. 

```c
/* Get an object's GC head */
#define AS_GC(o) ((PyGC_Head *)(o)-1)

/* Get the object given the GC head */
#define FROM_GC(g) ((PyObject *)(((PyGC_Head *)g)+1))
```

### gc_refs

`gc_refs` values determine if an object should be collected. When an object is malloc’ed, its `gc_refs` is set to `GC_UNTRACKED`, because it’s absent from any generation list. 

As soon as it’s added to a generation list its `gc_refs` is updated to GC_REACHABLE.

During a collection `gc_refs` may take other values. The most important is GC\_TENTATIVELY\_UNREACHABLE, which means the object has been moved to the unreachable set temporarily. Even when ref updating is over and an object is GC\_TENTATIVELY_UNREACHABLE, it may be made reachable again. 


## Summary

This article is a read-through of the `Modules/gcmodule.c` of the CPython interpreter. I explained my understanding of the `collect` method, which is called by `PyGC_collect` or `_PyObject_GC_Alloc`. The collecting process is outlined from preparing the generation, moving unreachable objects, recovering or deleting garbage to collecting and returning stats. The difference between a full collection and a collection of generation 0 or 1 is explained. Some heuristics and tips to use CPython efficiently were explained and internals of object allocation/collection were outlined. 
