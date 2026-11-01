#!/usr/bin/env bash
# Prints system usage as one line: cpu|ram%|ramGB|temp|rx|tx|disk%|diskUsedGB|diskTotalGB
# Without arguments it prints one line and exits.
# With --stream N it keeps running and prints a line every N seconds. The loop
# does not fork: /proc and /sys are read with builtins and df runs once a minute.

CACHE_DIR="${QS_RUN_SYSDATA:-${XDG_RUNTIME_DIR:-/tmp}/qs_sysdata}"
[ -d "$CACHE_DIR" ] || mkdir -p "$CACHE_DIR" 2>/dev/null

PREV_STAT_FILE="$CACHE_DIR/prev_stat"
TEMP_FILE="$CACHE_DIR/temp"
TEMP_TIME_FILE="$CACHE_DIR/temp_time"
DISK_FILE="$CACHE_DIR/disk"
DISK_TIME_FILE="$CACHE_DIR/disk_time"

read_cpu_net() {
    local cpu_id line stats r t _rest
    u2=0; n2=0; s2=0; i2=0; io2=0; ir2=0; so2=0; st2=0
    while read -r cpu_id u2 n2 s2 i2 io2 ir2 so2 st2 _rest; do
        [ "$cpu_id" = "cpu" ] && break
    done < /proc/stat

    rx2=0
    tx2=0
    while read -r line; do
        case "$line" in
            *[ew]*:*)
                stats="${line#*:}"
                read -r r _ _ _ _ _ _ _ t _rest <<< "$stats"
                rx2=$((rx2 + r))
                tx2=$((tx2 + t))
                ;;
        esac
    done < /proc/net/dev
}

load_prev_stat() {
    prev_time=""; u1=""; n1=""; s1=""; i1=""; io1=""; ir1=""; so1=""; st1=""; rx1=""; tx1=""
    [ -f "$PREV_STAT_FILE" ] && read -r prev_time u1 n1 s1 i1 io1 ir1 so1 st1 rx1 tx1 < "$PREV_STAT_FILE"
}

# CPU usage and network rates against the previous sample, $1 microseconds ago.
compute_rates() {
    local dt_us=$1
    CPU_USAGE=0
    RX_RATE=0
    TX_RATE=0
    [ -n "$st1" ] || return

    local total1=$((u1 + n1 + s1 + i1 + io1 + ir1 + so1 + st1))
    local total2=$((u2 + n2 + s2 + i2 + io2 + ir2 + so2 + st2))
    local diff_idle=$((i2 - i1))
    local diff_total=$((total2 - total1))
    if [ "$diff_total" -gt 0 ]; then
        CPU_USAGE=$(( 100 * (diff_total - diff_idle) / diff_total ))
    fi

    [ "$dt_us" -le 0 ] && dt_us=1000000
    if [ -n "$rx1" ] && [ "$rx2" -ge "$rx1" ] 2>/dev/null; then
        RX_RATE=$(( (rx2 - rx1) * 1000000 / dt_us ))
    fi
    if [ -n "$tx1" ] && [ "$tx2" -ge "$tx1" ] 2>/dev/null; then
        TX_RATE=$(( (tx2 - tx1) * 1000000 / dt_us ))
    fi
}

save_prev_stat() {
    echo "$NOW $u2 $n2 $s2 $i2 $io2 $ir2 $so2 $st2 $rx2 $tx2" > "$PREV_STAT_FILE"
    prev_time=$NOW; u1=$u2; n1=$n2; s1=$s2; i1=$i2; io1=$io2; ir1=$ir2; so1=$so2; st1=$st2; rx1=$rx2; tx1=$tx2
}

read_mem() {
    local key val
    TOTAL_MEM=0
    AVAIL_MEM=0
    while IFS=":" read -r key val; do
        case "$key" in
            MemTotal)
                val="${val% kB}"
                TOTAL_MEM="${val//[[:space:]]/}"
                ;;
            MemAvailable)
                val="${val% kB}"
                AVAIL_MEM="${val//[[:space:]]/}"
                ;;
        esac
        [ "$TOTAL_MEM" -gt 0 ] && [ "$AVAIL_MEM" -gt 0 ] && break
    done < /proc/meminfo

    local used=$((TOTAL_MEM - AVAIL_MEM))
    if [ "$TOTAL_MEM" -gt 0 ]; then
        RAM_PCT=$(( 100 * used / TOTAL_MEM ))
        RAM_GB="$(( used / 1048576 )).$(( (used % 1048576) * 10 / 1048576 ))"
    else
        RAM_PCT=0
        RAM_GB="0.0"
    fi
}

# Sets TEMP_PATH to the CPU temperature input, or leaves it empty.
find_temp_path() {
    local hwmon hwmon_name tz tz_type
    TEMP_PATH=""
    for hwmon in /sys/class/hwmon/hwmon*; do
        [ -f "$hwmon/name" ] || continue
        read -r hwmon_name < "$hwmon/name" 2>/dev/null
        case "$hwmon_name" in
            coretemp|k10temp|zenpower|cpu_thermal|bcm2835_thermal)
                if [ -f "$hwmon/temp1_input" ]; then
                    TEMP_PATH="$hwmon/temp1_input"
                    return
                fi
                ;;
        esac
    done

    for tz in /sys/class/thermal/thermal_zone*; do
        [ -f "$tz/type" ] || continue
        read -r tz_type < "$tz/type" 2>/dev/null
        case "$tz_type" in
            x86_pkg_temp|cpu_thermal|cpu-thermal)
                TEMP_PATH="$tz/temp"
                return
                ;;
        esac
    done

    if [ -r /sys/class/hwmon/hwmon0/temp1_input ]; then
        TEMP_PATH=/sys/class/hwmon/hwmon0/temp1_input
    elif [ -r /sys/class/thermal/thermal_zone0/temp ]; then
        TEMP_PATH=/sys/class/thermal/thermal_zone0/temp
    fi
}

read_temp() {
    local raw=""
    [ -n "$TEMP_PATH" ] && read -r raw < "$TEMP_PATH" 2>/dev/null
    if [ "${raw:-0}" -gt 1000 ] 2>/dev/null; then
        TEMP=$((raw / 1000))
    else
        TEMP=${raw:-0}
    fi
}

update_disk() {
    read -r DISK_PCT DISK_USED_GB DISK_TOTAL_GB <<< "$(df -Plk -x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs -x iso9660 2>/dev/null | awk '
    NR > 1 && $1 !~ /^\/dev\/loop/ && $1 != "udev" && $1 != "none" {
        if (!seen[$1]++) {
            total += $2
            used += $3
        }
    }
    END {
        if (total > 0) {
            pct = int((used / total) * 100 + 0.5)
            printf "%d %.1f %.1f\n", pct, used / 1048576, total / 1048576
        } else {
            print "0 0.0 0.0"
        }
    }')"
    DISK_PCT=${DISK_PCT:-0}
    DISK_USED_GB=${DISK_USED_GB:-0.0}
    DISK_TOTAL_GB=${DISK_TOTAL_GB:-0.0}
    echo "$DISK_PCT $DISK_USED_GB $DISK_TOTAL_GB" > "$DISK_FILE"
    echo "$NOW" > "$DISK_TIME_FILE"
    DISK_TIME=$NOW
}

# Reads the disk usage from the cache while it is younger than a minute.
load_disk() {
    DISK_TIME=0
    [ -f "$DISK_TIME_FILE" ] && read -r DISK_TIME < "$DISK_TIME_FILE" 2>/dev/null
    DISK_TIME=${DISK_TIME:-0}
    if [ -f "$DISK_FILE" ] && [ $((NOW - DISK_TIME)) -lt 60 ]; then
        read -r DISK_PCT DISK_USED_GB DISK_TOTAL_GB < "$DISK_FILE" 2>/dev/null
    else
        update_disk
    fi
}

print_usage() {
    echo "$CPU_USAGE|$RAM_PCT|$RAM_GB|$TEMP|$RX_RATE|$TX_RATE|$DISK_PCT|$DISK_USED_GB|$DISK_TOTAL_GB"
}

if [ "$1" = "--stream" ]; then
    interval=${2:-2}
    # read -t on a pipe nobody writes to waits like sleep, without a fork per tick.
    exec {sleep_fd}<> <(:)

    find_temp_path
    load_prev_stat
    prev_us=$(( ${prev_time:-0} * 1000000 ))
    NOW=${EPOCHREALTIME%%[!0-9]*}
    load_disk

    while :; do
        # EPOCHREALTIME uses the locale decimal separator, keep only the digits.
        now_us=${EPOCHREALTIME//[!0-9]/}
        NOW=$((now_us / 1000000))

        read_cpu_net
        compute_rates $((now_us - prev_us))
        save_prev_stat
        prev_us=$now_us

        read_mem
        read_temp
        [ $((NOW - DISK_TIME)) -ge 60 ] && update_disk

        print_usage || exit 0
        read -r -t "$interval" -u "$sleep_fd"
    done
fi

printf -v NOW "%(%s)T" -1

read_cpu_net
load_prev_stat
compute_rates $(( (NOW - ${prev_time:-0}) * 1000000 ))
save_prev_stat

read_mem

LAST_TEMP_TIME=0
[ -f "$TEMP_TIME_FILE" ] && read -r LAST_TEMP_TIME < "$TEMP_TIME_FILE" 2>/dev/null
LAST_TEMP_TIME=${LAST_TEMP_TIME:-0}
if [ -f "$TEMP_FILE" ] && [ $((NOW - LAST_TEMP_TIME)) -lt 6 ]; then
    read -r TEMP < "$TEMP_FILE" 2>/dev/null
    TEMP=${TEMP:-0}
else
    find_temp_path
    read_temp
    echo "$TEMP" > "$TEMP_FILE"
    echo "$NOW" > "$TEMP_TIME_FILE"
fi

load_disk

print_usage
