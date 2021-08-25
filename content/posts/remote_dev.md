+++
author = ["Petr Tikilyaynen"]
draft = false
+++

## <span class="org-todo done DONE">DONE</span> Remote (rust) development environment {#remote--rust--development-environment}


### Picture this at home {#picture-this-at-home}

Imaging you are working on a large Rust project. You have added a new feature,
wrote some tests and kick off the compile and test process. While you wait, you
switch to browsing Reddit. You like using a thin laptop - you can take it
anywhere and fit it into even the smallest bags. Your laptop starts churning
along, it's getting hotter under your hands and you see that Reddit is less
responsive. After several such compilation cycles, you notice that your battery
indicator has one bar left. You only unplugged it an hour ago and now you have
to go charge it again.

I found myself in that situation, when I started working on [tantivy](https://github.com/tantivy-search/tantivy/). During
winter months, using my laptop as an additional heater felt like a useful life
hack. Now that spring has sprung, I prefer to keep it cool. I decided to offload
CPU and RAM-intensive compilation and testing cycle to a remote machine.

This post outlines my system for saving battery and longevity of my laptop by
making someone else's computer suffer.

It's largely inspired by [pzmarzly's cloudy](https://github.com/pzmarzly/cloudy) project.


### MVP {#mvp}

Whenever possible, CPU-heavy compilation will take place on the VPS. All source
code changes will be updated, so at every point both local and VPS version of
the code match. If compilation and testing succeed, the executables are rsync'ed
from the VPS to my laptop.


### Do you always compile remotely? {#do-you-always-compile-remotely}

Obviously, if there is no internet connection and I cannot reach my droplet, it doesn't matter how big the repo is - I can only compile locally.

```shell
is_connected () {
  echo $(nc -z $VPS_IP 22)
}
```

Depending on the compile times of a given project network latency between the
compile droplet and my laptop might cancel out the time wins. I want to build a
general solution, so I need to decide when to compile locally or offload it
externally.

Using advanced ML algorithms and groundbreaking mathematical methods like linear
regression, I can classify if the compilation time is long enough to justify
offloading it to a VPS.

I use line count as a predictor for compile times that are long enough to be offloaded. Counts the total number of lines in .rs source files.

```shell
is_project_big () {
      # get a list of directories with interesting rust code - either src or tests
        DIRECTORIES=$(find . -maxdepth 1 -type d | grep "src\|test" | cut -c 3-);
        # get the total LoC in any .rs files in these directories
        LOC_IN_RUST_FILES=$(find $DIRECTORIES -type f -name "*.rs" | xargs wc -l | tail -1 | cut -d" " -f3);
        THRESHOLD_TO_COMPILE_REMOTELY=25000;
        if [ $LOC_IN_RUST_FILES -ge $THRESHOLD_TO_COMPILE_REMOTELY ]; then
            echo "true"
        else
            echo "false"
        fi
    }
```

At the time of writing tantivy has `35856` lines of Rust code.


### What do you need to compile remotely? {#what-do-you-need-to-compile-remotely}


#### Local config {#local-config}

Put this in a config\_remote\_dev

```shell
# insert your VPS IP
VPS_IP=XXX.XXX.XXX.XXX
FILE_CHANNEL_REUSE=1
# Send Cloudy config.
SEND_CLOUDY=0
# Send gitignore-d files.
SEND_GITIGNORE=0
# Send .git directory.
SEND_GIT=0
```


#### Configure cargo and necessary build tools on VPS {#configure-cargo-and-necessary-build-tools-on-vps}

I created a dedicated DigitalOcean droplet that will only be used for compiling large projects.

```shell
server_setup() {
    echo "Setting up server..."

    UTILS_CMD="
            echo apt-get install build-essential -y
            echo curl https://sh.rustup.rs -sSf \\| sh
            echo /root/.cargo/bin/rustup toolchain add stable
            echo /root/.cargo/bin/rustup default stable
        "
    echo "$UTILS_CMD" | m_ssh "$ID" "$IP" " bash -ls"

    echo "$ID $IP" > "$LOCAL_LOCKFILE"
}
```


#### <span class="org-todo todo TODO">TODO</span> sync all relevant files to a directory on the VPS {#sync-all-relevant-files-to-a-directory-on-the-vps}

First I need to sync files between my laptop and the VPS to make sure I am compiling the most current version.

```bash
m_rsync () {
    declare -a FLAGS
    FLAGS+=("-r" "-t" "-p" "-R" "-a" "-i" "-z") # t - timestamps, p - permissions
    ## You have to include first before excluding everything else. Order matters!
    # Copy all the files needed to build
    # Cargo.toml
    # rust_toolchain
    # src/*
    # tests/*
    # FLAGS+=("--exclude=.git*")

    FLAGS+=("--include=Cargo.toml")
    FLAGS+=("--include=rust_toolchain")
    FLAGS+=("--include=src/***")

    if [ -d tests ]; then
        FLAGS+=("--include=tests/***")
    fi

    # Exclude EVERYTHING else
    FLAGS+=("--exclude=*")
    rsync "${FLAGS[@]}" --list-only . | tail -20

    # if [ "$FILE_CHANNEL_REUSE" != "0" ]; then
    #     FLAGS+=("-e"
    #             "ssh -o ControlMaster=auto -o ControlPersist=600 -o ControlPath=~/.ssh/master-$1 -i $KEY_PATH")
    # fi
    # rsync "${FLAGS[@]}"
    # FLAGS+=("." "root@$2:~/cloudy/")
}

sync_files_over() {
    m_rsync $ID $IP &
    run_init
}
```


#### Pass my local compile commands over to the VPS {#pass-my-local-compile-commands-over-to-the-vps}

After that, I remotely pass my cargo command (usually `test`, but sometimes `build`) over ssh to cargo running on the VPS.

```shell
cmd_cmd() {
    assert_lockfile_present
    DIRNAME=$(basename "$PWD")
    # sync files over
    m_rsync $ID $IP $DIRNAME
    CMD=" cd $DIRNAME; $@"
    m_ssh $ID $IP " bash -ls -c \"$CMD\""
}
```


### <span class="org-todo todo TODO">TODO</span> What do you do with results? {#what-do-you-do-with-results}


#### <span class="org-todo todo TODO">TODO</span> Stream them back to terminal and watch results {#stream-them-back-to-terminal-and-watch-results}

-   <span class="org-todo todo TODO">TODO</span>  run the cargo command over ssh on remote and stream results

-   <span class="org-todo todo TODO">TODO</span>  check result - if 1, abort rest of script, deal with errors locally


#### <span class="org-todo todo TODO">TODO</span> Copy executables back to local target directory {#copy-executables-back-to-local-target-directory}

I also want to rsync the target directory back, so I can pull back executables to run locally.

-   <span class="org-todo todo TODO">TODO</span>  Check minimum number of executables to rsync from dev to laptop

    Check that that cargo run can work without any other libraries/binaries apart from \`target/release/executable\`.

-   <span class="org-todo todo TODO">TODO</span>  clean local target and rsync them back

-   <span class="org-todo todo TODO">TODO</span>  make sure it runs locally


### <span class="org-todo todo TODO">TODO</span> How does it fit into your normal workflow? <code>[0/2]</code> {#how-does-it-fit-into-your-normal-workflow}


#### <span class="org-todo todo TODO">TODO</span> Alias cargo to pt\_cargo {#alias-cargo-to-pt-cargo}


#### <span class="org-todo todo TODO">TODO</span> Write emacs integration to wrap it {#write-emacs-integration-to-wrap-it}


### How good is it? {#how-good-is-it}


#### Benefits {#benefits}

-   Fast builds! Keep the same laptop and get faster builds by getting a faster VPS.
-   Save disk space locally.


#### Disadvantages and additional requirements {#disadvantages-and-additional-requirements}

-   Need to keep the environment (Linux, environment vars, rust toolchain) in sync across machines.
-   If connection fails during a dev/debugging session, I won't have debug symbols or any dependencies locally, so will need to rebuild from scratch.
-   More network traffic - minor risk of hitting the bandwidth quota for my VPS. Minimise the risk by only mirroring to source code and release/debug binaries.
-   Not running into disk problems locally will make me forget how much I am using up in the VPS.


#### Results {#results}

After implementing this my compile-and-test cycle went from

Local build

```bash
cargo clean
time cargo test -q
```

Offload build

```bash
cargo clean
time cargo test -q
```

Aside from the times, I now don't need to worry about a hot laptop.
