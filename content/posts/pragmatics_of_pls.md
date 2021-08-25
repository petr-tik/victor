---
Title: "The pragmatics of programming languages"
Date: "2018-04-26"
Category: hacking
draft: true
Tags: [python, linguistics, semantics]
Author: Petr Tikilyaynen
description: "What is pythonic code in the theory of language"
---

Every programmer learning a new language goes through a code review, where they learn that their code isn't idiomatic. It sucks to hear, because it often lands on identity level. "You cannot write good Python/C++/Java/Haskell code" implies that you cannot write good code. Even if your co-worker corrects the code that you submitted now, it's hard to immediately internalise the conventions that make code more idiomatic.

I want to lend to software engineering the distinction between semantics and pragmatics, which is used in linguistics of natural languages. To echo [David Heinemeier Hansson's talk](https://www.youtube.com/watch?v=9LfmrkyP81M) reading and writing code is similar to literary analysis. I agree with him and find it useful to borrow categories from linguistics to programming languages. 


Semantics studies the literal meaning of atomic units of language (words). It explains why words mean what they do and where the meaning comes from. You can scan brain activity to establish neural connections between different words or analyse n-grams in texts to investigate most commonly occurring combinations of words. You then see if the words "dog" and "cat" activate the same areas of the brain and establish neural links and semantic web of associations. 


Pragmatics studies the difference between the literal meaning of a phrase and its intended meaning. Pragmatics can explain euphemisms, idioms (turns of phrase) and requests. The literal meaning of the question:

> Can you please open the window? 

Can be "transpiled" to 

> Are you capable of opening the window? 

In reality, however, the person asking the question means:

> Please open the window.


The literal meaning of:

> Break a leg! 

is misleading, because they are actually wishing you luck 

> Good luck for your performance! 


I will use examples from Python, the language I'm most proficient in and can easily think of examples. Please email me or open GitHub issues to add examples in your favourite language. 


Python is a good language for such examples. The zen of python and pythonic code style is well evangelised and documented. 

### Iterating over a collection vs list comprehension

List/set comprehensions are a Python syntactic feature for generating lists and sets concisely. 

```python
l1 = [x**2 for x in range(10)]
l1 = 

```

### Opening a file 

You can open a file by its filename to read its contents into memory or to make it available to the Python interpreter process under a file descriptor. 




Languages that offer a greater number of constructs to write software have a harder time defining such a standard.


C++ has a complicated history of big standard library vs boost and other external libraries, wider user base of experts adopting it for niche problems and Turing completeness (i.e. another language) in its template system. The pragmatics of using language features affects readability and performance in some cases (constexpr statements for compile-time evaluation). This makes it harder for everyone to agree on a C++-ic style that can be evangelised to the community. I know someone who happily uses templates wherever possible. I admit that they are much smarter and more tenacious than me (reading those template error messages requires perseverance). I also hope their use of templates doesn't prevent them from making friends at work. 




Further reading:

  * Unsurprisingly there is an [undergraduate course at Edinburgh university](https://www.inf.ed.ac.uk/teaching/courses/epl/), my alma mater, which analyses the pragmatics of different PLs. 
