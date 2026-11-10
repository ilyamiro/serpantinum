#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/config.sh"

qs_ensure_cache "calendar"

export LC_ALL=C

cache_dir="$QS_CACHE_DIR/calendar"
[[ -d "$cache_dir" ]] || mkdir -p "$cache_dir"
json_file="${cache_dir}/calendar.json"
raw_file="${cache_dir}/feed.ics"

ACTION="--getdata"
URL_ARG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --url)
            URL_ARG="$2"
            shift 2
            ;;
        --getdata|--json|--sync)
            ACTION="$1"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

if [[ "$ACTION" == "--json" ]]; then
    if [[ -f "$json_file" ]]; then
        cat "$json_file"
        exit 0
    else
        echo '{"lastSync":0,"events":{},"count":0}'
        exit 0
    fi
fi

# Determine Calendar URL
CAL_URL="$URL_ARG"
if [[ -z "$CAL_URL" ]]; then
    CAL_SETTINGS="$(get_setting "calendar" '{}')"
    CAL_URL="$(echo "$CAL_SETTINGS" | jq -r '.url // empty' 2>/dev/null)"
fi

if [[ -z "$CAL_URL" ]]; then
    echo '{"lastSync":0,"error":"No calendar URL configured","events":{},"count":0}' > "$json_file"
    cat "$json_file"
    exit 0
fi

# Fetch ICS
if ! curl -sL --max-time 15 "$CAL_URL" -o "$raw_file"; then
    if [[ -f "$json_file" ]]; then
        cat "$json_file"
    else
        echo '{"lastSync":0,"error":"Network fetch failed","events":{},"count":0}'
    fi
    exit 1
fi

# Parse ICS using Python standard library
python3 - "$raw_file" "$json_file" << 'EOF'
import sys, re, json, datetime

ics_path = sys.argv[1]
out_path = sys.argv[2]

try:
    with open(ics_path, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()
except Exception as e:
    sys.exit(1)

# Unfold lines (RFC 5545: lines folded with CRLF + space/tab)
content = re.sub(r"\r?\n[ \t]", "", content)

events_by_date = {}
total_events = 0

# Split into VEVENT blocks
vevents = re.findall(r"BEGIN:VEVENT(.*?)END:VEVENT", content, re.DOTALL)

def parse_date_value(val_str):
    # Formats: 20261109T143000Z, 20261109T143000, 20261109
    m = re.search(r"(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2}))?", val_str)
    if not m:
        return None, None
    year, month, day, hour, minute = m.groups()
    date_key = f"{year}-{month}-{day}"
    time_str = f"{hour}:{minute}" if hour and minute else "All Day"
    return date_key, time_str

def unescape_ics_text(txt):
    if not txt:
        return ""
    txt = txt.replace(r"\,", ",").replace(r"\;", ";").replace(r"\n", " ").replace(r"\N", " ").replace(r"\\", "\\")
    return txt.strip()

for ev in vevents:
    summary_m = re.search(r"^SUMMARY(?:;[^:]*)?:(.*)$", ev, re.MULTILINE)
    dtstart_m = re.search(r"^DTSTART(?:;[^:]*)?:(.*)$", ev, re.MULTILINE)
    dtend_m = re.search(r"^DTEND(?:;[^:]*)?:(.*)$", ev, re.MULTILINE)
    loc_m = re.search(r"^LOCATION(?:;[^:]*)?:(.*)$", ev, re.MULTILINE)
    
    if not dtstart_m:
        continue
        
    summary = unescape_ics_text(summary_m.group(1)) if summary_m else "Event"
    location = unescape_ics_text(loc_m.group(1)) if loc_m else ""
    
    start_date, start_time = parse_date_value(dtstart_m.group(1).strip())
    end_date, end_time = parse_date_value(dtend_m.group(1).strip()) if dtend_m else (None, None)
    
    if not start_date:
        continue

    item = {
        "summary": summary,
        "startTime": start_time or "All Day",
        "endTime": end_time or "",
        "location": location
    }
    
    if start_date not in events_by_date:
        events_by_date[start_date] = []
    events_by_date[start_date].append(item)
    total_events += 1

# Sort events on each day by startTime
for d in events_by_date:
    events_by_date[d].sort(key=lambda x: (x["startTime"] == "All Day", x["startTime"]))

output_data = {
    "lastSync": int(datetime.datetime.now().timestamp()),
    "count": total_events,
    "events": events_by_date
}

with open(out_path, "w", encoding="utf-8") as f:
    json.dump(output_data, f, indent=2)

EOF

if [[ -f "$json_file" ]]; then
    cat "$json_file"
fi
