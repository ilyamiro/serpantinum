source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh" 2>/dev/null || true

ACTION=${1:-get}

get_locks() {
    if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
        echo "0 0"
        return
    fi

    local caps=0
    local num=0
    local data
    data=$(LC_ALL=C hyprctl devices -j 2>/dev/null | jq -r '((.keyboards[] | select(.main == true)) // .keyboards[0]) | "\(.capsLock) \(.numLock)"' 2>/dev/null)
    if [[ "$data" =~ (true|false) ]]; then
        [[ "$data" =~ ^true ]] && caps=1
        [[ "$data" =~ true$ ]] && num=1
        echo "$caps $num"
        return
    fi

    grep -q '1' /sys/class/leds/*capslock*/brightness 2>/dev/null && caps=1
    grep -q '1' /sys/class/leds/*numlock*/brightness 2>/dev/null && num=1
    echo "$caps $num"
}

watch_locks() {
    if [ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
        exit 0
    fi

    if command -v python3 >/dev/null 2>&1; then
        exec python3 -u -c '
import glob, time, sys

caps_paths = glob.glob("/sys/class/leds/*capslock*/brightness")
num_paths = glob.glob("/sys/class/leds/*numlock*/brightness")

def read_state(paths):
    for p in paths:
        try:
            with open(p, "r") as f:
                if int(f.read().strip() or 0) > 0:
                    return 1
        except Exception:
            pass
    return 0

last_caps = read_state(caps_paths)
last_num = read_state(num_paths)
count = 0

while True:
    time.sleep(0.02)
    count += 1
    if count >= 50:
        count = 0
        caps_paths = glob.glob("/sys/class/leds/*capslock*/brightness")
        num_paths = glob.glob("/sys/class/leds/*numlock*/brightness")

    c = read_state(caps_paths)
    if c != last_caps:
        last_caps = c
        sys.stdout.write(f"capslock {c}\n")
        sys.stdout.flush()

    n = read_state(num_paths)
    if n != last_num:
        last_num = n
        sys.stdout.write(f"numlock {n}\n")
        sys.stdout.flush()
'
    fi

    local last_c=-1 last_n=-1 c n f val
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

        if [ "$last_c" -ne -1 ] && [ "$c" -ne "$last_c" ]; then
            echo "capslock $c"
        fi
        if [ "$last_n" -ne -1 ] && [ "$n" -ne "$last_n" ]; then
            echo "numlock $n"
        fi
        last_c=$c
        last_n=$n
        sleep 0.03
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
