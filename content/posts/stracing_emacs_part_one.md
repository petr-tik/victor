---
Title: "Stracing emacs. Part 1"
Date: "2017-03-28"
categories: hacking
draft: true
tags: [linux, strace, emacs]
Author: Petr Tikilyaynen
description: "Investigating what emacs is doing on startup"
---

In this series of posts, I investigate and report Emacs start-up procedure and how to optimise it. Emacs is a beautiful OS with a built-in ELisp interpreter and some text editing capabilities. 

I used strace by examining the start up of emacs. [My emacs config is different](https://github.com/petr-tik/emacs-config) and will be compared to a vanilla emacs start-up. For each syscall I investigated and summarised return values, their frequency to find out how I can improve it. 

I ran the command below, waited until emacs was fully loaded and quit it. -C combines -c with normal output i.e. it printed each syscall, while the process was live and finished the file with the summary table.

```bash
strace -C -o emacs_strace_output emacs
```

## Format

I will choose different parameters by which I will choose syscalls to analyse. Then I use the manpage, my favourite search engine (CrouchCrouchWalk) to write up my understanding of the processes.



## Top 10 by time

From the `man strace | grep -A 4 sort` page - Strace can sort by time, calls, name, and nothing (default is time). For data consistency, I will use the same output file and awk magic.


```bash
$$$$ tail -n 69 emacs_strace_output | head -n 12
% time     seconds  usecs/call     calls    errors syscall
------ ----------- ----------- --------- --------- ----------------
 27.05    0.000109           0     18973     17979 open
 23.33    0.000094           0      5192      3609 recvmsg
 15.88    0.000064           0      2432           munmap
 13.65    0.000055           0      3179           poll
  8.44    0.000034           0      3208         1 read
  6.45    0.000026           0      1610           writev
  2.73    0.000011           0      5127           lseek
  2.48    0.000010           0      1005           close
  0.00    0.000000           0        14           write
  0.00    0.000000           0       605       119 stat
```

## open

Syscall that usually takes a pointer to const array of chars for pathname and an int for flags. Flags carry information about access modes (read-only, write-only or read-n-write) and file status flags. 

Returns an int that is a file descriptor (non-negative int), which other syscalls in the process will use to access the same file. There is no need to randomly assign fd numbers, so they are given out in ascending order. 

#### Errors: 

Used the magic of grep and awk to extract, count and summarise the number of times each return value (including errors) occured.

```bash
grep "^open" emacs_strace_output | awk 'BEGIN { FS=")" } { print $2 }' | awk '{ print $2}' | sort | uniq -c | sort -nr
```

`grep "open(" emacs_strace_output`- returns the lines with open syscall trace. "^open(" guarantees that we only examine lines starting with "open"

`awk 'BEGIN { FS=")"} { print $2 }'`

Takes the lines and prints column 2 after the ")" separator, which comes at the end of the open syscall. Return values come in different formats

```bash
 -1 ENOENT (No such file or directory)
 8
```

So we need another awk with a different FS (field separator) variable.

`awk '{ print $2}'` - which uses the default field separator " " and prints the second column, which will be the return value.

Successful return is a positive int file descriptor, a negative return value can be looked up in the man page for open. Sorting arranges values return values in order, so ```uniq -c``` can summarise and return the count of each value followed by the value. ```sort -nr``` sorts it by numeric value in descending order of counts. 

Below is the end bash one-liner and the resulting table.

```bash
$$$$ echo "count   ret_val"; grep "^open(" emacs_strace_output | awk 'BEGIN { FS=")" } { print $2 }' | awk '{ print $2}' | sort | uniq -c | sort -nr
count   ret_val
  17979 -1
    624 7
    131 8
     86 3
     83 9
     20 6
     15 4
     11 11
     10 5
      6 10
      5 14
      2 12
      1 13
```

As seen in the summary, 17979 open syscalls returned the error value -1, which stands for ENOINT - no such file or directory. Judging by the greatest return value, not more than 14 files are open simultaneously during the start-up process. 18973 - 17979 = 994 and there are 1005 succesful ```close``` syscalls, so 11 times an fd must have been closed and reused. 

Looking at each open syscall with return value 7. 

```bash
$$$ grep "^open" emacs_strace_output | awk 'BEGIN { FS="\"| " } { print $2,$6 }' | grep " 7" | awk '{ print $1 }' | sort | uniq -c | sort -nr
     23 /usr/share/icons/default/index.theme
     12 /home/petr_tik/.emacs.d/elpa/dash-20161121.55/dash-autoloads.el
      8 /home/petr_tik/.emacs.d/elpa/s-20140714.707/s-autoloads.el
      6 /usr/share/emacs/24.5/lisp/emacs-lisp/cl-seq.elc
      6 /home/petr_tik/.emacs.d/elpa/json-snatcher-20150511.2047/json-snatcher-autoloads.el
      6 /home/petr_tik/.emacs.d/elpa/json-reformat-20160212.53/json-reformat-autoloads.el
      ...
      more filespaths
```

shows that several files are repeatedly opened on the same file descriptor. 

Looking at the usr/share/icons/default/index.theme

```bash
$$$$ grep -n "usr/share/icons/default/index.theme" emacs_strace_output 
1530:open("/usr/share/icons/default/index.theme", O_RDONLY) = 6
3412:open("/usr/share/icons/default/index.theme", O_RDONLY) = 7
3446:open("/usr/share/icons/default/index.theme", O_RDONLY) = 7
    ...
    more filespaths
```

we take the line numbers where /usr/share/icons/default/index.theme appears and examine a typical case of such a syscall. The first line it is opened under fd 6, so we take the needed number of lines (head for first 1549 lines, out of which we will need the last 20). 

```bash
$$$ head -n 1535 emacs_strace_output | tail -n 6
open("/usr/share/icons/default/index.theme", O_RDONLY) = 6
fstat(6, {st_mode=S_IFREG|0644, st_size=32, ...}) = 0
mmap(NULL, 4096, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7f24722d7000
read(6, "[Icon Theme]\nInherits=DMZ-White\n", 4096) = 32
close(6)                                = 0
munmap(0x7f24722d7000, 4096)            = 0
```

after opening the file, emacs runs fstat on the given file descriptor. After that, 4096 bytes of memory is mapped.

## recvmsg

syscall to receive messages from a socket. Came from 4.4BSD (sockets were a BSD invention).

Input is a socket file descriptor int, pointer to the struct of type msghdr and int for flags. If succesful, they return the length of the receied message. -1 is the error ret value. Summary table shows >3000 error returns, which are investigated below.

recvmsg uses the pointer to the msghdr struct to minimise the number of arguments. 

#### Errors:

```bash
$$$ echo "freq    ret_val"; grep "^recvmsg(" emacs_strace_output | awk 'BEGIN { FS=") "} { print $2 }' | awk ' { print $2 } ' | sort | uniq -c | sort -nr
freq    ret_val
   3609 -1
   1369 32
     97 224
     44 48
     17 64
     17 40
      8 96
      5 36
      4 128
      3 4096
      3 1360
      2 76
      2 160
      1 896
      1 832
      1 56
      1 336
      1 3348
      1 3316
      1 268
      1 256
      1 208
      1 1948
      1 1236
      1 1188

```

The number of -1 matches the one 3609 in the summary table confirming that the bash oneliner was correct. The return value is usually the number of bytes read from the socket, which we can expect to be a power of 2. 

```bash
$$$$ echo "   freq socket_descriptor"; grep "^recvmsg(" emacs_strace_output | grep -v "= -1" | awk 'BEGIN { FS="\\\\(+|,+" } { print $2 }' | uniq -c
   freq socket_descriptor
   1583 5
```

grep for all recvmsg syscalls, which don't return a -1 error value. NB "\\\\(" escapes the bracket character and returns the first argument of each recvmsg syscall invocation. uniq -c returns the frequncy for each value. It turned out that emacs listens on only one socket file descriptor (happens to be number 5). Further inspection didn't give too much information.

## munmap

Evil brother of mmap (more info below), which deletes the mappings for the specified address. After that, all references to addresses in that range (addr + length) are invalidated. NB - closing a file descriptor doesn't unmap the region, which means for security you want to close fds and then unmap the region. 

Input:
    pointer of type void to address 
    size_t length
    
Returns:
    0 if succesful
    -1 on failure

mmap - takes more parameters like flags and protection flags, which determine the access rights to those pages. 

Examining output. No errors, just invocation patterns. 

##### bash command

```bash
$$$$ grep "^munmap(" emacs_strace_output | awk -F",|\\\\)" '{ print $2 }' | sort | uniq -c | sort -nr
```

1. grep for munmap at the beginning of the line - as before
2. awk with 2 field separators comma "," and closing bracket ")"
3. print the second column, which will be the size_t var for length of region to unmap. 
4. sort all occurences of each size_t
5. count each uniq value and return a table of counts
6. sort the table in descending order


```bash
$$$$ echo "   freq  size_t"; grep "^munmap(" emacs_strace_output | awk -F",|\\\\)" '{ print $2 }' | sort | uniq -c | sort -nr
   freq  size_t
   2067  69632
    265  4096
     84  790528
      5  117548
      2  565248
      2  245760
      2  2339
      1  99000
      1  606208
      1  475136
      1  424408
      1  122880
```

Funny values of size\_t. I found 2339 an interesting value for size_t and deciding to dig into it. 

```bash
grep -n "^munmap(" emacs_strace_output | grep ", 2339"
1016:munmap(0x7f24722d7000, 2339)            = 0
1023:munmap(0x7f24722d7000, 2339)            = 0
```
returns the matched lines with the line number from the original strace_file. So I made a head and tail pipe, which opens the relevant region of the strace output. [oh that's a bingo!](https://www.youtube.com/watch?v=Zk5Il6KQrd8) - it happens to be the region, when /etc/passwd was opened. 

```bash
$$$$ head -n 1024 emacs_strace_output | tail -n 14
open("/etc/passwd", O_RDONLY|O_CLOEXEC) = 4
lseek(4, 0, SEEK_CUR)                   = 0
fstat(4, {st_mode=S_IFREG|0644, st_size=2339, ...}) = 0
mmap(NULL, 2339, PROT_READ, MAP_SHARED, 4, 0) = 0x7f24722d7000
lseek(4, 2339, SEEK_SET)                = 2339
munmap(0x7f24722d7000, 2339)            = 0
close(4)                                = 0
open("/etc/passwd", O_RDONLY|O_CLOEXEC) = 4
lseek(4, 0, SEEK_CUR)                   = 0
fstat(4, {st_mode=S_IFREG|0644, st_size=2339, ...}) = 0
mmap(NULL, 2339, PROT_READ, MAP_SHARED, 4, 0) = 0x7f24722d7000
lseek(4, 2339, SEEK_SET)                = 2339
munmap(0x7f24722d7000, 2339)            = 0
close(4)                                = 0
```

    
## poll

Similar to select syscall, only newer. ppoll is newer still. Waits for one of a set of fds to come available for IO operations. 

Input:
    pointer to struct of type pollfd - carries the filedescriptor int and requested events
    nfds_t - number of file descriptors to watch
    timeout - milliseconds the syscall can block while waiting for an fd to be ready. It can be interrupted by a signal hanlder. You can set an infinite timeout with a negative value.

Returns:
    if succesful - positive number of structures with several returned event fields. 
    0 if timed out and/or no fds became ready
    -1 on error

#### Inspecting

```bash
$$$$ grep "^poll(" emacs_strace_output | awk -F" =" ' { print $2 }' | awk -F" |=|," '{ print $2 }' | sort | uniq -c
     61 0
   3118 1
```

61 poll calls timed out. 

## read

Tries to read bytes from a given file descriptor into a buffer. 

Gotcha: if count > SSIZE_MAX, the result is unspecified.

Input:
    file descriptor 
    pointer to buf
    count of type size_t 
    
Returns:
    if successfully read - returns int number of read bytes, by which the file position is also advanced. The return value may be less than the count (bytes that were requested to read), if a signal interrupts the syscall or we reach EOF. 
    on error, -1 is set to errno. Unspecified if the file position value changes. 
    
The only error happens when we try to read from the paredit.elc file descriptor.

```bash
$$$$ grep -n "^open(.* = 7\|^read(.* = -1" emacs_strace_output | tail -n 2
50481:open("/home/petr_tik/.emacs.d/elpa/paredit-20140128.1248/paredit.elc", O_RDONLY|O_CLOEXEC) = 7
51237:read(7, 0x7fffe3761b80, 16)             = -1 EAGAIN (Resource temporarily unavailable)
```


## writev

Writes given buffers of data to a given file descriptor. Similar to write, but sequentially goes through all the buffers. 

Returns:
    number of bytes written.
    -1 if error

#### Inspecting

```bash
$$$$ grep "^writev(" emacs_strace_output | awk -F"\\\\(|," ' {print $2}' | sort | uniq -c
   1610 5
```

All writev syscalls take file descriptor 5. Is it a coincidence?

#### Errors

None


## lseek

Given a file descritpor, offset and whence parameters, reposition the offset on the file descriptor. It can move the offset beyond the file size. 

Returns: resulting offset location (in bytes) from the beginning of the file.

#### Errors

None

## close

Does what it says on the tin. Closes a given file desciptor, which allows the int value to be reused. It can return an error and you better check the return value to avoid nasty bugs. It can be interrupted by a signal, in which case it doesn't close the file. Prone to race conditions.

#### Errors

None

## write

writes to a given file descriptor.

#### Errors

None


## stat

Like the terminal stat command, returns the status of a file at a given pathname.


#### Errors

Confirming that the bash one-liner catches all the errors.

```bash
$$$$ grep "^stat(.* = -1" emacs_strace_output | wc -l
119
```

Now print the list of pathnames that return errors and the ret_values.

```bash
$$$$ grep "^stat(.* = -" emacs_strace_output | awk -F"\\\\(\"|\",| =| " ' { print $2, $6 }' | sort
```

Most errors have the value of -1, which according to error section in the `man 2 stat` is ENOENT A  component  of  pathname  does  not exist, or pathname is an empty string.





