---
title: "Talebian software development"
date: "2018-03-10"
category: hacking
tags: ["thoughts"]
draft: false
author: Petr Tikilyaynen
description:  "Philosophical ideas behind development practices"
---

Having read Nicholas Nassim Taleb, I noticed 2 ideas of his overlaping with software development practices. 

## Antifragile as chaos engineering, fuzzing and testing

Taleb coins the term antifragile to emphasise a class of organisms and organisations that evolve under external stress. The word is contrasted to fragile and robust, which worsens or remains the same (up to a point) respectivly. Combined with the inability to predict the future, antifragile organisms are those that will improve when subject to unpredictable external stress. Given the second law of thermodynamics (total entropy of a closed system can't decrease), fragile systems are expected to degrade with time, while antifragile systems get stronger. 

I find that similar to chaos engineering, fuzzing and testing. 

### Antifragility of distributed systems

Chaos engineering is promoted by Netflix as a way of simulating controlled, but random failure in a distributed system to test that the services run uninterrupted. Netflix devs cannot predict, which disk, machine or DC will fail, so they developed a service, [Chaos Monkey](https://github.com/Netflix/chaosmonkey) that simulates such failures. 

A given machine may be serving applications to generate a landing page for a new login, suggest a 'next to watch' for someone else and running a keyword search for another user. Each of these services is developed by a dedicated team that designs and implements solutions using domain knowledge. An operations administrator/SRE doesn't have the domain context in his head, if the application fails, so if chaos monkey hits, operations will take longer to solve the problem. 

Signalling to developers at Netflix that their services will be subject to random failure, integrates the idea of antifragility from the stage of design and follows into the code. 

### Antifragility of an application

#### Testing

An application running on one given host has fewer moving parts, but can break under unaccounted-for inputs. Buffer overflow attacks is a good example of a developer being bitten by assuming that the world will treat their application nicely. Testing is like scars, it tells a new developer on the team, which edge cases were originally unaccounted for and how they affected the application. 


#### Fuzzing

If your application has a large surface and takes many types of input, you don't have the time to think and write tests for all of them. You can write another application that will generate those inputs (according to rules or randomly) for your application. This helps developers test their application in the background, uncovering cases they would have not thought about. 


## Skin in the game is DevOps

Skin in the game is Taleb's most recent book that outlines a code of ethics. According to skin in the game, people that verbally promote behaviors or actions (investment advice, any kind of sales really) should be exposed to losses, if their suggestions backfire on the suckers, who took their advice. 

DevOps is broadly understood as a practice of writing and supporting your own code in production. In contrast to having a wall between developers writing business logic and operations supporting those applications in the wild. Developers will care much more about implementing logging and monitoring, if they have to debug their own applications at 3AM on Saturday. I have been told that debugging a Google Cloud DC, while on a conference call with the VP of a major client, is a strong incentive to improve monitoring for the future. 

Anecdotically, large organisations (like banks) that split development from operations, end up with worse code quality and costlier operations. Developers, who write, compile and throw binaries over to operations without worrying about the complications arising from real workloads, don't care if the application hogs all the RAM on a given machine or bottlenecks IO for other processes. 

Learning languages (for programming computers and talking to people) taught me to draw parallels and see common patterns between ideas in seemingly unrelated domains. In my view, there are strong similarities between Taleb's ideas and the principles programmers use to improve the quality of software. 
