---
Title: "Roll your own windows in emacs-gdb"
Date: "2017-07-14"
draft: true
categories: hacking
tags: emacs
Author: Petr Tikilyaynen
description: "Customising the layout of gdb-many-windows in emacs"
---

## Plan

Level up my emacs skills by using gdb for debudding Cpp/C programmes. Make it easy to debug them by defining and enabling custom window layout.


### Layout


     +--------------------------------|--------------------------------+
     |   GUD interaction buffer       |   Locals/Registers buffer      |
     |--------------------------------|--------------------------------+
     |                                |                                |
     |                                |                                | 
     |                                |                                |
     |   Source buffer                |   Stack frames of pgm          |
     |                                |                                |
     |                                |                                |
     |                                |                                |
     |--------------------------------|--------------------------------+
     |   IO for debugged pgm          |   Breakpoints/Threads buffer   |
     +--------------------------------|--------------------------------+
