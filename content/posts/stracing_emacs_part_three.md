---
Title: "Stracing emacs. Part 3"
Date: "2017-04-04"
Category: hacking
draft: true
Tags: [linux, tracing, emacs]
Author: Petr Tikilyaynen
description: "Investigating what emacs is doing on startup"
---

## emacs syscalls

The emacs git repo has the source code for the .c files that define wrapper functions for the respective syscalls. This is done to account for different OSes providing different kernel specification. It might be helpful to look at the source code for the different syscalls.

## Top 10 by errors

I won't repeat the same syscalls I investigated in previous parts, just the new ones. 

```bash
$$$$ tail -n 67 emacs_strace_output | head -n 65 | awk -F" " ' { print $5, $6 }' | grep ^[0-9] | sort -nrk1
17979 open
3609 recvmsg
1446 faccessat
1143 readlinkat
119 stat
117 access
4 connect
2 statfs
2 rt_sigreturn
2 recvfrom
2 getxattr
1 wait4
1 read
```

1. Take the summary table from the bottom of the output file. 
2. Discard the bottom lines 
3. take the last 2 columns (split by whitespace), which should give us the number of errors and the syscall. If no errors are present, it will just output the syscall name
4. Leave only the lines starting with a number i.e. those with a number of errors > 0
5. numerically sort (in reverse order) by the values in the first column 


## faccessat

```bash
grep "^faccessat" emacs_strace_output | grep -v " = 0"
```

### Sys call

Checks if the user has permission to access the file.

Input:
  * int for directory file descriptor. The `AT_FDCWD` macro used to indicate current working directory. You can set another directory file descriptor and the pathname will be evaluated with respect to a different directory.
  * pathname
  * mode of access - F_OK checks for existence, R_OK, W_OK and X_OK for reading, writing and executing respectively.


### Errors

Files that couldn't be accessed, because they don't exist. 

```bash
faccessat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/highlight-indentation-20161012.209.signed", F_OK) = -1 ENOENT (No such file or directory)
faccessat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/ido-ubiquitous-20140526.1306.signed", F_OK) = -1 ENOENT (No such file or directory)
faccessat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/irony-20170313.1437.signed", F_OK) = -1 ENOENT (No such file or directory)
faccessat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/ivy-20170202.223.signed", F_OK) = -1 ENOENT (No such file or directory)
faccessat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/json-mode-20160803.1606.signed", F_OK) = -1 ENOENT (No such file or directory)
.
.
.
$$$$ grep "^faccessat" emacs_strace_output | grep -v " = 0" | grep -c ".signed"
82
$$$$ tree ~/.emacs.d/elpa/ | grep -c ".signed"
6
$$$$ grep "^faccessat" emacs_strace_output | grep -c "W_OK"
8
$$$$ grep "^faccessat" emacs_strace_output | grep -c "W_OK) = 0"
0
$$$$ grep "^faccessat" emacs_strace_output | grep -v " = 0" | grep -c "R_OK"
111
$$$$ grep "^faccessat" emacs_strace_output | grep -v " = 0" | grep -c "X_OK"
76
```


111 files couldn't be read by emacs. 

82 .signed files couldn't be accessed and only 6 .signed files are in the directory (recursively checking). 

Write access:
All 8 files emacs wants to write to can be accessed. 

Read access

## readlinkat

### Sys call

Follows and reads a value from a symbolic link into a given buffer. Successful calls return the number of bytes written to buffer, errors return -1.

### Source

From the [emacs Github Mirror](https://github.com/emacs-mirror/emacs/blob/master/lib/readlinkat.c)

### Errors

```bash
$$$$ grep "^readlinkat" emacs_strace_output | grep -v " = 0" | awk -F '-1 | \\(' '{ print $2}' | sort -n | uniq -c
      5 
   1139 EINVAL
      4 ENOENT
```

ENOENT - is when the given file doesn't exist. 
EINVAL - either the bufsiz isn't positive or the given pathname isn't a symbolic link

```bash
$$$$ grep "^readlinkat" emacs_strace_output | grep -v " = 0" | gawk -F", " ' { print $3 }' | sort | uniq -c | sort -nk1
.
.
.
      1 0x7fffe375fc80
      1 0x7fffe375fcf0
      1 0x7fffe375fd70
      1 0x7fffe375fd90
      1 0x7fffe375fdd0
      1 0x7fffe375fe30
      1 0x7fffe375fea0
.
.
.
     30 0x7fffe375ee30
     30 0x7fffe3760060
     30 0x7fffe3760210
     30 0x7fffe37603c0
     30 0x7fffe3760570
     30 0x7fffe3760720
     36 0x7fffe375f220
     36 0x7fffe3760450
     36 0x7fffe3760600
     36 0x7fffe3760960
     36 0x7fffe3760b10
     37 0x7fffe37607b0
```

Shows the number of times different errors were thrown for each of the virtual memory addresses. 

An interesting case is 0x7fffe3760720, which happens to be the address into which all autoloads .el files are read into. Autoloads is a facility in emacs, which allows lazy loading of a preregistered function at runtime. 

```bash
$$$$ grep "^read.*0x7fffe3760720" emacs_strace_output | wc -l
30
$$$$ grep "^read.*0x7fffe3760720" emacs_strace_output
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/ntlm-2.1.0/ntlm-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/s-20140714.707/s-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/dash-20161121.55/dash-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/s-20140714.707/s-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/dash-20161121.55/dash-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/pkg-info-20140610.630/pkg-info-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/async-20161103.1036/async-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/dash-20161121.55/dash-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/git-commit-mode-20140605.520/git-commit-mode-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/git-rebase-mode-20140605.520/git-rebase-mode-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/json-reformat-20160212.53/json-reformat-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/json-snatcher-20150511.2047/json-snatcher-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/ivy-20170202.223/ivy-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/company-20170112.2005/company-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/find-file-in-project-20161202.2205/find-file-in-project-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/highlight-indentation-20161012.209/highlight-indentation-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/pyvenv-20160527.442/pyvenv-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/yasnippet-20170127.2128/yasnippet-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/s-20140714.707/s-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/dash-20161121.55/dash-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/docker-tramp-20161020.2220/docker-tramp-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/magit-popup-20161222.428/magit-popup-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/s-20140714.707/s-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/tablist-20160424.235/tablist-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/json-mode-20160803.1606/json-mode-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/clojure-mode-20141120.1410/clojure-mode-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/clojure-mode-20141120.1410/clojure-mode-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/dash-20161121.55/dash-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/pkg-info-20140610.630/pkg-info-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
readlinkat(AT_FDCWD, "/home/petr_tik/.emacs.d/elpa/queue-0.1.1/queue-autoloads.el", 0x7fffe3760720, 1024) = -1 EINVAL (Invalid argument)
```


## access

### syscall

Given a pathname string and an int for mode, check if the file at the pathname can be accessed in a given mode.

### source
