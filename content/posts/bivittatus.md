---
title: "Search text fast or die trie-ing"
date: "2018-02-12"
categories: hacking
draft: false
tags: 
 - python
 - c
Author: Petr Tikilyaynen
description: "Writing a Python extension in C"
---

Benchmarking the Python and C implementation of a trie-as-a-dictionary. 

## What is the problem? 

Searching for words in the dictionary is a tough problem. If the dictionary is sorted, you can implement binary search, but even then you can spend the worst-case time looking for a word that is not there. English prohibits some sequences of letters like `zv`, `sdr` and others. Checking the first 2 letters of such words will be faster than binary searching the whole dictionary. When the dictionary isn't sorted alphabetically, but according to a different parameter, it's even worse. 

## What data structure can we use instead? 

Enter trie or prefix tree, a data structure that stores nodes with characters in the same order as they are in the word. It requires breaking words into a linked list of character nodes with an array of pointers to children nodes.

A depth-first search from the head node will recreate all the words in the dictionary and we can save memory consumption by reusing prefixes common to many words. 

I wrote the same trie implementation in C and Python and benchmarked both to see which one is faster. 

## What does C give you over Python?

C is closer to the metal, saves memory for data structures and is compiled. The cTrie is implemented as a struct with 1 trie_node object and the PyObject\_Head that is compulsory for Python extensions. This is lighter on methods and thus memory used than the PyTrie class, which inherits unnecessary methods from the Base Object. 

As far as I know, Python converts variable names to memory addresses, so using pointers in the cTrie implementation doesn't give an advantage over PyTrie.

Characters are the same in C and Python - the CPython interpreter caches useful strings and individual characters are resolved as pointers to the immutable strings of characters. 


## How much infra is there for writing Python extensions in C? 

Loads. The CPython developers are great, there are helper methods to parse arguments passed to the function and cast them to given C types, debug print method, method to build return values and for the method definitions. The documentation is detailed and includes a tutorial, which helps. 

[Series of tutorials](https://docs.python.org/3/extending/index.html) for rolling your own Python3 extension. 


### Debugging

After installing debug symbols

```bash
sudo apt-get install python3.5-dbg
```

Compile the extension with `-g -O0` flags to make sure debug sybmols are available and compiler optimisations (gcc is clever nowadays) don't remove too much of your code. 

Run the line below (inside emacs or terminal).

```bash
gdb -ex r --args python3 test.py
```

You can step through the programme, look at the backtrace and examine registers. 

## Building

Using distutils Extension class we only need to give our module a name that agrees with the tp_name as defined in the source and a list of source files. We can even pass compile flags to turn optimisations on/off.

An object file is compiled in a temp build/ directory. The object file is used to compile a shared library compiled to the root of the project directory.

## Running and testing

After a build is succesful, cTrie is available to any python programme that is run inside the root directory. I wrote tests to make sure both PyTrie and cTrie implementations pass the same test suite. 

Using pytest and its mark.parametrize decorator, I define a list of parameters (different trie constructors) and make sure each test function is run with every trie constructor.

```python
import pytest

from ctrie import cTrie
from py_trie import PyTrie

constructors = [cTrie, PyTrie]

@pytest.mark.parametrize("constructor", constructors)
def test_find_added(constructor):
    tr = constructor()
    tr.add("bob")
    assert tr.find("bob") == 1
```

## What's inside the shared library

Using objdump, we can examine the functions of the shared library.

```bash
objdump -d ctrie.cpython-35m-x86_64-linux-gnu.so 
```

eg. the shared library has a `char_to_ascii` function used to calculate the index of the character in the english alphabet i.e. a gives 0, z - 26. This index is used to retrieve the relevant child node to continue building or querying the trie.

```asm
0000000000000b40 <char_to_ascii>:
 b40:	40 0f be c7          	movsbl %dil,%eax
 b44:	83 e8 61             	sub    $0x61,%eax
 b47:	c3                   	retq   
 b48:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 b4f:	00 
```

%dil is the lowest 8 bits of the DI register, one of the core registers. Core registers are available in 32-bit and 16-bit modes. We are working with 1 char - 1 byte = 8 bits, so the CPython compiler order to use 8 bits of one of the core registers. 

movsbl - reads the value and moves into into the %eax register after sign-extending it to 32 bits. 

after that, constant hex value of 0x61 is substituted from the %eax register. hex works in powers of 16, making 0x61 = 6 * 16 + 1 * 16 ^ 0 = 97. 

retq jumps back to the return address that should be in the stack frame, but my understanding is getting quite hand-wavy here. 


Now that we know that ctrie shared library is a set of instructions that is exposed to the CPython interpreter, we can dig deeper into it or run the benchmark suite.


## What performs better - compiled C or Python?

The benchmark compiled a fresh version of the library, cleared all caches and run the `benchmark.py` script. 

```python
building 'ctrie' extension
creating build
creating build/temp.linux-x86_64-3.5
x86_64-linux-gnu-gcc -pthread -DNDEBUG -g -fwrapv -O2 -Wall -Wstrict-prototypes -g -fstack-protector-strong -Wformat -Werror=format-security -D_FORTIFY_SOURCE=2 -fPIC -I/usr/include/python3.5m -c trie.c -o build/temp.linux-x86_64-3.5/trie.o -O3
x86_64-linux-gnu-gcc -pthread -shared -Wl,-O1 -Wl,-Bsymbolic-functions -Wl,-Bsymbolic-functions -Wl,-z,relro -Wl,-Bsymbolic-functions -Wl,-z,relro -g -fstack-protector-strong -Wformat -Werror=format-security -D_FORTIFY_SOURCE=2 build/temp.linux-x86_64-3.5/trie.o -o /home/petr_tik/Coding/bivittatus/ctrie.cpython-35m-x86_64-linux-gnu.so
free && sync && sudo sh -c "echo 3 > /proc/sys/vm/drop_caches" && free

...

python3 benchmark.py
PyTrie
Takes 0.000009s to instantiate before adding sorted words
Takes 0.231256s to add 18000 words
Takes 0.000593s to instantiate before adding random words
Takes 0.239599s to add 18000 random words
Takes 0.005769s to find 100 random words
Takes 0.001648s to look for, but fail to find, 800 missing words
cTrie
Takes 0.000529s to instantiate before adding sorted words
Takes 0.012475s to add 18000 words
Takes 0.000002s to instantiate before adding random words
Takes 0.011485s to add 18000 random words
Takes 0.000142s to find 100 random words
Takes 0.000375s to look for, but fail to find, 800 missing words
```

The C trie is faster in all cases apart from instantiating a new trie. As far as I understand, this is related to the fact that the bytecode for PyTrie is preloaded by the CPython interpreter, while the C library needs to load when it's first called. After that the speed improvement is at least a factor of 2. Searching for words inside the trie is an order of magnitude faster. 


## Where is the source? 

[On my GitHub](https://github.com/petr-tik/bivittatus). Feel free to open issues or send PRs. 


## Why is it called bivittatus?

Bivittatus `is one of the five largest species of snakes in the world` according to wikipedia. Seemed appropriate to name a Python extension after one of the longest types of Python in the world.


## tl; dr

Writing own toy Python extension in C is fun, gives you a big performance win for limited investment and is easy thanks to great documentation and tooling. 
