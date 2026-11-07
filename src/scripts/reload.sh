#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"
bash "$SERPANTINUM_DIR/scripts/refresh_daemons.sh" >/dev/null 2>&1
quickshell -p "$MAIN_QML" ipc call main forceReload
