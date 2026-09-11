#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh" 2>/dev/null || true

ACTION="${1:-get}"

get_locks() {
    local caps=0
    local num=0
    local data=""

    if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] && command -v hyprctl >/dev/null 2>&1; then
        data=$(LC_ALL=C hyprctl devices -j 2>/dev/null | jq -r '((.keyboards[] | select(.main == true)) // .keyboards[0]) | "\(.capsLock) \(.numLock)"' 2>/dev/null)
        if [[ "$data" =~ (true|false) ]]; then
            [[ "$data" =~ ^true ]] && caps=1
            [[ "$data" =~ true$ ]] && num=1
            echo "$caps $num"
            return
        fi
    fi

    for f in /sys/class/leds/*capslock*/brightness; do
        if [ -r "$f" ]; then
            read -r val < "$f" 2>/dev/null
            if [ "${val:-0}" -gt 0 ] 2>/dev/null; then
                caps=1
                break
            fi
        fi
    done

    for f in /sys/class/leds/*numlock*/brightness; do
        if [ -r "$f" ]; then
            read -r val < "$f" 2>/dev/null
            if [ "${val:-0}" -gt 0 ] 2>/dev/null; then
                num=1
                break
            fi
        fi
    done

    echo "$caps $num"
}

watch_locks() {
    if command -v python3 >/dev/null 2>&1; then
        exec python3 -u -c '
import glob, os, select, struct, sys, time

is_64bit = struct.calcsize("P") == 8
event_fmt = "qqHHi" if is_64bit else "iiHHi"
event_size = struct.calcsize(event_fmt)

def read_sysfs(pattern):
    for path in glob.glob(pattern):
        try:
            with open(path, "r") as f:
                if int(f.read().strip() or 0) > 0:
                    return 1
        except Exception:
            pass
    return 0

last_caps = read_sysfs("/sys/class/leds/*capslock*/brightness")
last_num = read_sysfs("/sys/class/leds/*numlock*/brightness")

def find_kbd_devices():
    devs = glob.glob("/dev/input/by-id/*-event-kbd")
    if not devs:
        devs = glob.glob("/dev/input/by-path/*-event-kbd")
    if not devs:
        devs = glob.glob("/dev/input/event*")
    return devs

fds = {}
for path in find_kbd_devices():
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
        fds[fd] = path
    except Exception:
        pass

if fds:
    while True:
        try:
            rlist, _, _ = select.select(list(fds.keys()), [], [])
            for fd in rlist:
                while True:
                    try:
                        buf = os.read(fd, event_size)
                        if not buf or len(buf) < event_size:
                            break
                        _, _, ev_type, ev_code, ev_val = struct.unpack(event_fmt, buf)
                        if ev_type == 17:
                            if ev_code == 1:
                                val = 1 if ev_val > 0 else 0
                                if val != last_caps:
                                    last_caps = val
                                    sys.stdout.write(f"capslock {val}\n")
                                    sys.stdout.flush()
                            elif ev_code == 0:
                                val = 1 if ev_val > 0 else 0
                                if val != last_num:
                                    last_num = val
                                    sys.stdout.write(f"numlock {val}\n")
                                    sys.stdout.flush()
                    except (BlockingIOError, InterruptedError):
                        break
                    except Exception:
                        break
        except Exception:
            time.sleep(1)
else:
    caps_paths = glob.glob("/sys/class/leds/*capslock*/brightness")
    num_paths = glob.glob("/sys/class/leds/*numlock*/brightness")
    count = 0
    while True:
        time.sleep(0.08)
        count += 1
        if count >= 60:
            count = 0
            caps_paths = glob.glob("/sys/class/leds/*capslock*/brightness")
            num_paths = glob.glob("/sys/class/leds/*numlock*/brightness")
        c = 0
        for p in caps_paths:
            try:
                with open(p, "r") as f:
                    if int(f.read().strip() or 0) > 0:
                        c = 1
                        break
            except Exception:
                pass
        if c != last_caps:
            last_caps = c
            sys.stdout.write(f"capslock {c}\n")
            sys.stdout.flush()
        n = 0
        for p in num_paths:
            try:
                with open(p, "r") as f:
                    if int(f.read().strip() or 0) > 0:
                        n = 1
                        break
            except Exception:
                pass
        if n != last_num:
            last_num = n
            sys.stdout.write(f"numlock {n}\n")
            sys.stdout.flush()
'
    fi

    local last_c=-1 last_n=-1 c n f val
    for f in /sys/class/leds/*capslock*/brightness; do
        if [ -r "$f" ]; then
            read -r val < "$f" 2>/dev/null
            if [ "${val:-0}" -gt 0 ] 2>/dev/null; then
                last_c=1
                break
            fi
        fi
    done
    [ "$last_c" -eq -1 ] && last_c=0

    for f in /sys/class/leds/*numlock*/brightness; do
        if [ -r "$f" ]; then
            read -r val < "$f" 2>/dev/null
            if [ "${val:-0}" -gt 0 ] 2>/dev/null; then
                last_n=1
                break
            fi
        fi
    done
    [ "$last_n" -eq -1 ] && last_n=0

    while true; do
        c=0
        for f in /sys/class/leds/*capslock*/brightness; do
            if [ -r "$f" ]; then
                read -r val < "$f" 2>/dev/null
                if [ "${val:-0}" -gt 0 ] 2>/dev/null; then
                    c=1
                    break
                fi
            fi
        done

        n=0
        for f in /sys/class/leds/*numlock*/brightness; do
            if [ -r "$f" ]; then
                read -r val < "$f" 2>/dev/null
                if [ "${val:-0}" -gt 0 ] 2>/dev/null; then
                    n=1
                    break
                fi
            fi
        done

        if [ "$c" -ne "$last_c" ]; then
            echo "capslock $c"
            last_c=$c
        fi
        if [ "$n" -ne "$last_n" ]; then
            echo "numlock $n"
            last_n=$n
        fi
        sleep 0.1
    done
}

case "$ACTION" in
    get)
        get_locks
        ;;
    watch)
        watch_locks
        ;;
    *)
        get_locks
        ;;
esac
