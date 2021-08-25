+++
title = "Using Docker to reproduce a read-only file system"
author = ["Petr Tikilyaynen"]
date = 2019-06-18T22:23:00+01:00
lastmod = 2019-06-18T23:45:58+01:00
tags = ["rust", "tantivy"]
categories = ["hacking"]
draft = false
description = "The educational benefits of reproducing bugs"
+++

This is part 2 of my journey adding read-only mode to [tantivy](https://github.com/tantivy-search/tantivy/). It started, when a user reported a [bug](https://github.com/tantivy-search/tantivy/issues/557) of an application failing to open an index on a read-only file system.

Before implementing the read-only feature, I would like to a) reproduce the bug b) step through it with a debugger to see what causes the error.

In the [previous post]({{< relref "permissions_arent_mounts" >}}), we found that removing write and execute permissions on files and directory of the tantivy index doesn't simulate a read-only file system.

So we are back to the drawing board for ideas on how to reproduce the bug.

One way of simulating a different OS configuration locally is to use Docker.

Docker is a ~~fad~~ system that allows you to specify, build and run snapshoted applications.


## How do you build a container? {#how-do-you-build-a-container}

First let's define a docker image in a Dockerfile.

```Dockerfile
FROM ubuntu:18.04
COPY open_in_dir /repro/open_in_dir
# copies file_on_host path_on_container/file_on_host
```

This builds on top of the ubuntu 18.04 image, which provides compatibility with my host.

The `COPY` command copies the open\_in\_dir executable to a repro directory of the container.

Make sure the Dockerfile and the open\_in\_dir executable are in the small\_index directory locally run the following command.

```bash
$$$$ sudo docker build -t tantivy_cont .
Sending build context to Docker daemon  63.84MB
Step 1/2 : FROM ubuntu:18.04
 ---> 7698f282e524
Step 2/2 : COPY open_in_dir /repro/open_in_dir
 ---> Using cache
 ---> 442ddff8340e
Successfully built 442ddff8340e
Successfully tagged tantivy_cont:latest
```

We have built a container image and tagged it with tantivy\_cont.


## So you built a container, now what? {#so-you-built-a-container-now-what}

We have successfully specified a container image that includes our open\_in\_dir executable in a repro directory.

On Linux, Docker relies on 2 OS primitives: control groups and namespaces.
One of the namespaces is the mount namespace, which allows you to mount a specific fs point into your process. To the container it looks like the subdir in a subdir on the host is one of the top directories in its file system.

When running the container, we can mount `pwd`, which is the small\_index/ directory on the host, as a **read-only** small\_index/ directory in the repro dir on the container.

For more information run `man 7 namespaces` in your terminal.

```bash
$$$$:/tantivy/small_index sudo docker run -v `pwd`:/repro/small_index:ro -it tantivy_cont
root@21541302399e:/# cd repro
root@21541302399e:/repro# ls -al
total 62328
drwxr-xr-x 1 root root     4096 Jun 18 21:09 .
drwxr-xr-x 1 root root     4096 Jun 18 21:09 ..
-rwxrwxr-x 1 root root 63810624 Jun 18 18:24 open_in_dir
drwxr-xr-x 2 1000 1000     4096 Jun 18 21:04 small_index
root@21541302399e:/repro# touch small_index/meta.json
touch: cannot touch 'small_index/meta.json': Read-only file system
root@21541302399e:/repro# cat /proc/mounts | grep "small"
/dev/sda7 /repro/small_index ext4 ro,relatime,data=ordered 0 0
```

We are now the `root` user in a running container. We can check that our executable and the small\_index dir are here as expected.

If we try to `touch` one of the files in the small\_index/ directory, we will get rejected, because it's a read-only file system and touch wanted to modify the file.

Looking inside the container-wide `/proc/mounts` we find that small\_index/ is indeed read-only - `ro`.

The stage is set. We have a read-only file system running inside the container with our executable and the index directory.


## We only need to run the executable... {#we-only-need-to-run-the-executable-dot-dot-dot}

...and we should see the "Read-only file system" error message thrown by `Index::open_in_dir` as reported in the ticket.

So we run it.

```bash
root@21541302399e:/repro# ./open_in_dir
Successfully opened the index
```

{{< figure src="/images/me_vs_filesystem.gif" >}}


## What have I learnt? {#what-have-i-learnt}

As it stands, I have found a configuration in which tantivy fails to open an
index inside a given directory. I tried to simulate a read-only file system by removing write and execute permissions from file and directory of the index. That proved useless (it threw an error, but not what was expected), so I decided to simulate the whole fs to be read-only.

Using Docker I mounted the index directory of the host into a running container, where the application successfully opened the index.

I have exhausted my creativity to come up with a repro, so I will have to implement read-only mode relying on my understanding of tantivy internals rather than fs configuration.
