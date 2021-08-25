---
title: "Puzzles in C++"
date: "2017-03-21"
category: hacking
tags: [cpp, puzzles, algorithms]
author: Petr Tikilyaynen
draft: true
description: "Getting my head around C++ with a small puzzle"
---

Notes on working with C++, my understanding of the small set of syntax features and data structures available. Might read like obvious or wrong set of assumptions to an experienced C++ engineer. Will keep updating with newer puzzles. 


## Namespaces

Define the set of functions, which are used during method name resolution. @jbcoe suggested to avoid it, as it can get messy with several conflicting namespaces.

Adding this to the top of the file
```cpp
using namespace std;
```

defines where method names will be looked up, which would save 5 chars

```cpp
cout
```

instead of 

```cpp
std::cout
```


## Data structures

Used stringstream object, which inherits from input_ and output_ streams. 


## Misc C++ 

Using clang++, -std=c++11 with awesome features like auto for type inference in for-loops

## DNA counting puzzle

Given a DNA string, return the counts of each char (A, C, G, T). Initial solution - make a map with char as key and count <int> as value. Considering that the structure won't need to grow and we know the full range of characters that can appear, we can optimise. Instead, use an array and an enum to index into the cell in the array. Each value is started at 0 and as we iterate over the string, the value at the relevant index is incremented. That way, we can guarantee using one L1 cache line (4 ints = 16 bytes) and a buffer for the string. For further optimisation, we can implement a streaming buffer, if we are sure the string will only be used once. 
