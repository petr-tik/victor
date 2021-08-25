---
title: "Getting clojure with Lisp"
date: "2016-02-20"
category: hacking
draft: false
tags: [clojure]
authors: Petr Tikilyaynen
description: "My story with Clojure"
---

I have spent the weekend reading and getting my head around Clojure and here are my first thoughts.

It's definitely a great exercise and even if I will never get to write a single line of code in a functional language in my life, I will be more confident using map, filter and reduce in python. 

Adopting the immutable data approach, makes me really concentrate on the quality and good compositionality of the functions, where I really think through how to make a series of pure functions, whose output will feed into the next one's input well. WHile REPL-based development is helpful to try defn functions on the fly to experiment, my python background is annoyed that I cannot just print the state of the programme at every step: 
i) pure functions are stateless
ii) pure functions have no side effect like printing to the stdout

As this is an exercise in thinking and writing pure functions, printing to stdout is betraying the clojure way and would involve a helper function that needs to wrap each function and print the arguments and output. 

Going forward, I've been told 4Clojure is a good source of problems and the TDD framework is very thorough. Another upside of pure functions I hope to experience soon is the ease of unit testing them. If you write all helper functions and main the UNIX way, you should be able to test each of them separately and when composed with easy input. 

A good exercise, which lends itself nicely to Clojure is checking if a given word and any word from a vector of words have are anagrams. 

	#!clojure
	(defn anagram?
  	"Takes 2 words - returns True if they are anagrams, false otherwise"
  		[word1 word2]
  		(if (= (frequencies word1) (frequencies word2))
    		true
    		false
    		))

	(defn anagrams
  	"Takes a target word and a vector of words 
  	Returns a list of anagrams of the target from the vector"
  	[target-word list-of-words]
  	(filter (fn [candidate-word] 
		(anagram? target-word candidate-word)) list-of-words))
