#!/usr/bin/env bash
is_connected () {
    echo $(nc -z $VPS_IP 22)
}

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

cmd_cmd() {
    assert_lockfile_present
    DIRNAME=$(basename "$PWD")
    # sync files over
    m_rsync $ID $IP $DIRNAME
    CMD=" cd $DIRNAME; $@"
    m_ssh $ID $IP " bash -ls -c \"$CMD\""
}

#!/usr/bin/env bash
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
