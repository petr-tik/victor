#!/usr/bin/env bash

# Cloudy: supercharge your workflow with cloud workers
# Copyright (C) 2019 Paweł Zmarzły
#
# This program is free software; you can redistribute it and/or modify it under the terms of the GNU
# General Public License as published by the Free Software Foundation; either version 2 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with this program; if not,
# write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.

set -eu

source "remote_dev.sh"

# Constants

GLOBAL_CONF=~/.cloudy
LOCAL_CONF=.cloudy
LOCAL_LOCKFILE=.cloudy-server-running

# Defaults

KEY_PATH=~/.ssh/id_rsa
FILE_CHANNEL_REUSE=1
VPS_IP="68.183.46.238"

# Load config

if [ -f $GLOBAL_CONF ]; then
    . $GLOBAL_CONF
fi

if [ -f $LOCAL_CONF ]; then
    . $LOCAL_CONF
fi

if [ -f $LOCAL_LOCKFILE ]; then
    ID=$(cat $LOCAL_LOCKFILE | cut -f1 -d' ')
fi

if [ -f $LOCAL_LOCKFILE ]; then
    IP=$(cat $LOCAL_LOCKFILE | cut -f2 -d' ')
fi

# Utilities

assert_lockfile_present() {
    if [ ! -f $LOCAL_LOCKFILE ]; then
        echo "Server not running!"
        echo "$LOCAL_LOCKFILE was not found. Start with \"cloudy init\"."
        exit 1
    fi
}

assert_lockfile_absent() {
    if [ -f $LOCAL_LOCKFILE ]; then
        echo "Server already running!"
        echo "Check server status and remove $LOCAL_LOCKFILE if it is not."
        exit 1
    fi
}

# Network utilities

m_ssh() {
    FLAGS=("-o" "ControlMaster=auto"
        "-o" "ControlPersist=600"
        "-o" "ControlPath=~/.ssh/master-$1"
        "-i" "$KEY_PATH"
        "root@$2" "$3")
    ssh "${FLAGS[@]}"
}

cmd_ssh() {
    assert_lockfile_present
    m_rsync $ID $IP
    m_ssh $ID $IP
}


subcommand=$1
case $subcommand in
    "" | "-h" | "--help" | "help")
        print_help
        ;;
    "-v" | "--version" | "version")
        print_version
        ;;
    *)
        shift
        cmd_${subcommand} $@
        ;;
esac
exit 0
