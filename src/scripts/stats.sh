#!/usr/bin/env bash
# ==============================================================================
# Hacker Stats Provider (CPU & GPU)
# Latency: < 1ms
# ==============================================================================

# 1. CPU
CACHE_FILE="/dev/shm/qs_cpu_cache"
read -r _ u n s i w x y z _ < /proc/stat
total=$((u + n + s + i + w + x + y + z))
idle=$((i + w))

cpu_pct=0
if [[ -f "$CACHE_FILE" ]]; then
    read -r prev_total prev_idle < "$CACHE_FILE"
    diff_total=$((total - prev_total))
    diff_idle=$((idle - prev_idle))
    if (( diff_total > 0 )); then
        cpu_pct=$(( (1000 * (diff_total - diff_idle) / diff_total + 5) / 10 ))
        (( cpu_pct < 0 )) && cpu_pct=0
        (( cpu_pct > 100 )) && cpu_pct=100
    fi
fi
echo "$total $idle" > "$CACHE_FILE"

# 2. Intel GPU (RC6 Residency Engine)
gpu_pct=0
GPU_CACHE="/dev/shm/qs_gpu_cache"
RC6_FILE="/sys/class/drm/card1/device/drm/card1/gt/gt0/rc6_residency_ms"
if [[ ! -f "$RC6_FILE" ]]; then
    RC6_FILE=$(ls /sys/class/drm/*/device/drm/*/gt/gt0/rc6_residency_ms 2>/dev/null | head -1)
fi

if [[ -n "$RC6_FILE" && -f "$RC6_FILE" ]]; then
    read -r current_rc6 < "$RC6_FILE"
    current_time=$(date +%s%3N)

    if [[ -f "$GPU_CACHE" ]]; then
        read -r prev_time prev_rc6 < "$GPU_CACHE"
        time_diff=$(( current_time - prev_time ))
        rc6_diff=$(( current_rc6 - prev_rc6 ))

        if (( time_diff > 0 )); then
            idle_pct=$(( (100 * rc6_diff) / time_diff ))
            gpu_pct=$(( 100 - idle_pct ))
            (( gpu_pct < 0 )) && gpu_pct=0
            (( gpu_pct > 100 )) && gpu_pct=100
        fi
    fi
    echo "$current_time $current_rc6" > "$GPU_CACHE"
fi

# Consolidate JSON output
printf '{"cpu": %d, "gpu": %d}\n' "$cpu_pct" "$gpu_pct"
