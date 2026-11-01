VERBOSE=0
if [[ "${1:-}" == "--verbose" ]]; then
    VERBOSE=1
fi

if [ -n "${MANGO_INSTANCE_SIGNATURE:-}" ] && command -v mmsg &>/dev/null && command -v jq &>/dev/null; then
    if [ "$VERBOSE" -eq 1 ]; then
        out=$(mmsg get all-monitors 2>/dev/null | jq -r '.monitors[]? | select(.active) | "\(.name)|\(.width)x\(.height)|60.00"' 2>/dev/null)
    else
        out=$(mmsg get all-monitors 2>/dev/null | jq -r '.monitors[]? | select(.active) | .name' 2>/dev/null)
    fi
    if [ -n "$out" ]; then
        echo "$out"
        exit 0
    fi
fi

if command -v hyprctl &>/dev/null; then
    if [ "$VERBOSE" -eq 1 ]; then
        out=$(hyprctl monitors 2>/dev/null | awk '/^Monitor /{name=$2; got_mode=0} !got_mode && /^[[:space:]]+[0-9]+x[0-9]+@[0-9.]+/{split($1,a,"@"); printf "%s|%s|%.2f\n", name, a[1], a[2]; got_mode=1}')
    else
        out=$(hyprctl monitors 2>/dev/null | awk '/^Monitor /{print $2}')
    fi
    if [ -n "$out" ]; then
        echo "$out"
        exit 0
    fi
fi

if command -v niri &>/dev/null; then
    if [ "$VERBOSE" -eq 1 ]; then
        if command -v jq &>/dev/null; then
            out=$(niri msg --json outputs 2>/dev/null | jq -r 'to_entries[]? | .value | "\(.name)|\(.current_mode.width // .modes[.current_mode].width)x\(.current_mode.height // .modes[.current_mode].height)|\((.current_mode.refresh_rate // .modes[.current_mode].refresh_rate // 60000) / 1000 | string | tonumber | . * 100 | round / 100)"' 2>/dev/null)
        fi
        if [ -z "$out" ]; then
            out=$(niri msg outputs 2>/dev/null | awk '/^Output /{gsub(/[" :]/, "", $2); name=$2} /Current mode:|[0-9]+x[0-9]+@[0-9.]+/{for(i=1;i<=NF;i++){if($i~/^[0-9]+x[0-9]+@[0-9.]+/){split($i,a,"@"); printf "%s|%s|%.2f\n", name, a[1], a[2]; name=""} else if($i~/^[0-9]+x[0-9]+$/ && $(i+1)=="@"){dim=$i; fps=$(i+2); gsub(/Hz/,"",fps); printf "%s|%s|%.2f\n", name, dim, fps; name=""}}}')
        fi
    else
        if command -v jq &>/dev/null; then
            out=$(niri msg --json outputs 2>/dev/null | jq -r 'keys[]?, .[].name?' 2>/dev/null | grep -v '^null$' | awk '!seen[$0]++ && NF')
        fi
        if [ -z "$out" ]; then
            out=$(niri msg outputs 2>/dev/null | awk '/^Output /{gsub(/[" :]/, "", $2); print $2}')
        fi
    fi
    if [ -n "$out" ]; then
        echo "$out"
        exit 0
    fi
fi

if command -v swaymsg &>/dev/null; then
    if [ "$VERBOSE" -eq 1 ]; then
        if command -v jq &>/dev/null; then
            out=$(swaymsg -t get_outputs -r 2>/dev/null | jq -r '.[] | select(.active) | "\(.name)|\(.current_mode.width)x\(.current_mode.height)|\((.current_mode.refresh / 1000) * 100 | round / 100)"' 2>/dev/null)
        fi
        if [ -z "$out" ]; then
            out=$(swaymsg -t get_outputs 2>/dev/null | awk '/"name":/{gsub(/[",]/, "", $2); name=$2} /"active": true/{active=1} /"width":/{gsub(/[,]/, "", $2); w=$2} /"height":/{gsub(/[,]/, "", $2); h=$2} /"refresh":/{gsub(/[,]/, "", $2); fps=$2/1000} /^[[:space:]]*},?[[:space:]]*$/{if(active && name!="" && w!="" && h!=""){printf "%s|%sx%s|%.2f\n", name, w, h, (fps?fps:60.00)}; name=""; w=""; h=""; fps=""; active=0}')
        fi
    else
        if command -v jq &>/dev/null; then
            out=$(swaymsg -t get_outputs -r 2>/dev/null | jq -r '.[] | select(.active) | .name' 2>/dev/null)
        fi
        if [ -z "$out" ]; then
            out=$(swaymsg -t get_outputs 2>/dev/null | awk '/"name":/{gsub(/[",]/, "", $2); n=$2} /"active": true/{print n}')
        fi
    fi
    if [ -n "$out" ]; then
        echo "$out"
        exit 0
    fi
fi

if command -v wlr-randr &>/dev/null; then
    if [ "$VERBOSE" -eq 1 ]; then
        out=$(wlr-randr 2>/dev/null | awk '/^[a-zA-Z0-9-]+ /{name=$1} /current/{dim=""; fps="60.00"; for(i=1;i<=NF;i++){if($i~/^[0-9]+x[0-9]+$/) dim=$i; if($(i+1)=="Hz") fps=$i}; if(name!="" && dim!=""){printf "%s|%s|%.2f\n", name, dim, fps; name=""}}')
    else
        out=$(wlr-randr 2>/dev/null | awk '/^[a-zA-Z0-9-]+ /{print $1}')
    fi
    if [ -n "$out" ]; then
        echo "$out"
        exit 0
    fi
fi

if command -v xrandr &>/dev/null; then
    if [ "$VERBOSE" -eq 1 ]; then
        out=$(xrandr --query 2>/dev/null | awk '/ connected/{name=$1; dim=""; for(i=1;i<=NF;i++){if($i~/^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$/){split($i,p,"+"); dim=p[1]}}} /^\s+[0-9]+x[0-9]+/ && /\*/{if(dim=="") dim=$1; fps="60.00"; for(i=1;i<=NF;i++){if($i~/\*/){v=$i; gsub(/[\*+]/,"",v); fps=v}}; if(name!=""){printf "%s|%s|%.2f\n", name, dim, fps; name=""}}')
    else
        out=$(xrandr --query 2>/dev/null | awk '/ connected/{print $1}')
    fi
    if [ -n "$out" ]; then
        echo "$out"
        exit 0
    fi
fi

for status in /sys/class/drm/card*-*/status; do
    if [ -f "$status" ] && [ "$(cat "$status")" = "connected" ]; then
        dev=$(dirname "$status")
        name=$(basename "$dev")
        name="${name#card*-}"
        if [ "$VERBOSE" -eq 1 ]; then
            if [ -f "$dev/modes" ]; then
                mode=$(head -n 1 "$dev/modes")
                echo "$name|$mode|60.00"
            else
                echo "$name|Unknown|60.00"
            fi
        else
            echo "$name"
        fi
    fi
done
