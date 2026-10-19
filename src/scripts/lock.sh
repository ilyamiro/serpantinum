#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"
qs_ensure_cache "lock"

case "$1" in
    --static) action="activateStatic" ;;
    --reauth) action="restartAuth" ;;
    *) action="activate" ;;
esac

quickshell -p $MAIN_QML ipc call lock "$action"
