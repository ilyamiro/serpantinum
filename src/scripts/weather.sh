#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/config.sh"
source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/i18n.sh"

qs_ensure_cache "weather"

export LC_ALL=C

cache_dir="$QS_CACHE_WEATHER"
json_file="${cache_dir}/weather.json"
view_file="${cache_dir}/view_id"

VERBOSE=false
ACTION=""
DIRECTION=""
LOC_ARG=""
UNIT_ARG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --location)
            LOC_ARG="$2"
            shift 2
            ;;
        --unit)
            UNIT_ARG="$2"
            shift 2
            ;;
        --getdata|--json|--view-listener|--icon|--temp|--hex|--current-icon|--current-temp|--current-hex)
            ACTION="$1"
            shift
            ;;
        --nav)
            ACTION="$1"
            DIRECTION="$2"
            shift 2
            ;;
        *)
            if [[ -z "$ACTION" ]]; then
                ACTION="$1"
            fi
            shift
            ;;
    esac
done

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "\e[1;34m[WEATHER-DEBUG]\e[0m $1" >&2
    fi
}

UNIT="${UNIT_ARG:-${WEATHER_UNIT:-${OPENWEATHER_UNIT:-metric}}}"
log_debug "Using weather unit profile: $UNIT"

case "$UNIT" in
    "imperial") UNIT_SYM="°F" ;;
    "standard") UNIT_SYM="K" ;;
    *) UNIT_SYM="°C" ;;
esac

mkdir -p "${cache_dir}"

get_weather_i18n_json() {
    jq -n \
        --arg sunny "$(t "weather.desc.sunny")" \
        --arg clear "$(t "weather.desc.clear")" \
        --arg cloudy "$(t "weather.desc.cloudy")" \
        --arg mist "$(t "weather.desc.mist")" \
        --arg rainy "$(t "weather.desc.rainy")" \
        --arg snow "$(t "weather.desc.snow")" \
        --arg storm "$(t "weather.desc.storm")" \
        --arg unknown "$(t "weather.desc.unknown")" \
        '{
            sunny: $sunny,
            clear: $clear,
            cloudy: $cloudy,
            mist: $mist,
            rainy: $rainy,
            snow: $snow,
            storm: $storm,
            unknown: $unknown
        }'
}

get_location() {
    if [[ -n "$LOC_ARG" && "$LOC_ARG" != "null" && "$LOC_ARG" != "{}" ]]; then
        echo "$LOC_ARG"
        return
    fi
    local gen_json loc_json
    gen_json="$(get_setting "general" '{}')"
    loc_json="$(echo "$gen_json" | jq -c '.location // empty' 2>/dev/null)"

    if [[ -z "$loc_json" || "$loc_json" == "null" ]]; then
        script_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
        if [[ "$VERBOSE" == "true" ]]; then
            loc_json="$("${script_dir}/location.sh" --verbose)"
        else
            loc_json="$("${script_dir}/location.sh")"
        fi
    fi
    echo "$loc_json"
}

write_dummy_data() {
    log_debug "Writing fallback dummy data to $json_file"
    local desc_offline
    desc_offline="$(t "weather.desc.offline")"
    final_json="["
    for i in {0..4}; do
        future_date=$(date -d "+$i days")
        f_day_raw=$(date -d "$future_date" "+%a")
        f_full_day_raw=$(date -d "$future_date" "+%A")
        f_m_raw=$(date -d "$future_date" "+%b")
        f_d_raw=$(date -d "$future_date" "+%d")

        f_day="$(t "weather.days.${f_day_raw,,}")"
        f_full_day="$(t "weather.days.${f_full_day_raw,,}")"
        f_month="$(t "weather.months.${f_m_raw,,}")"
        f_date_num="${f_d_raw} ${f_month}"

        final_json="${final_json} {
            \"id\": \"${i}\",
            \"day\": \"${f_day}\",
            \"day_full\": \"${f_full_day}\",
            \"date\": \"${f_date_num}\",
            \"max\": \"0.0\",
            \"min\": \"0.0\",
            \"feels_like\": \"0.0\",
            \"wind\": \"0\",
            \"humidity\": \"0\",
            \"pop\": \"0\",
            \"icon\": \"\",
            \"hex\": \"#cdd6f4\",
            \"desc\": \"${desc_offline}\",
            \"hourly\": [{\"time\": \"00:00\", \"temp\": \"0.0\", \"icon\": \"\", \"hex\": \"#cdd6f4\"}]
        },"
    done
    final_json="${final_json%,}]"
    echo "{ \"latitude\": 0.0, \"longitude\": 0.0, \"location_updated_at\": 0, \"unit\": \"${UNIT}\", \"unit_sym\": \"${UNIT_SYM}\", \"current_temp\": \"0.0\", \"current_temp_formatted\": \"0.0${UNIT_SYM}\", \"current_icon\": \"\", \"current_hex\": \"#cdd6f4\", \"forecast\": ${final_json} }" > "${json_file}"
}

get_data() {
    log_debug "Entering get_data routine..."
    loc_json=$(get_location)
    
    lat=$(echo "$loc_json" | jq -r '.latitude // empty' 2>/dev/null)
    lon=$(echo "$loc_json" | jq -r '.longitude // empty' 2>/dev/null)
    tz=$(echo "$loc_json" | jq -r '.timezone // empty' 2>/dev/null)
    loc_ts=$(echo "$loc_json" | jq -r '.updated_at // 0' 2>/dev/null)

    [[ -z "$lat" || "$lat" == "null" ]] && lat="0.0"
    [[ -z "$lon" || "$lon" == "null" ]] && lon="0.0"
    [[ -z "$tz" || "$tz" == "null" ]] && tz="auto"
    [[ -z "$loc_ts" || "$loc_ts" == "null" ]] && loc_ts=0

    log_debug "Resolved coordinates -> Lat: $lat, Lon: $lon, Timezone: $tz"

    case "$UNIT" in
        "imperial")
            OM_TEMP_UNIT="&temperature_unit=fahrenheit"
            OM_WIND_UNIT="&wind_speed_unit=mph"
            IS_KELVIN=false
            ;;
        "standard")
            OM_TEMP_UNIT=""
            OM_WIND_UNIT=""
            IS_KELVIN=true
            ;;
        *)
            OM_TEMP_UNIT=""
            OM_WIND_UNIT=""
            IS_KELVIN=false
            ;;
    esac

    forecast_url="https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&timezone=${tz}&current=temperature_2m,weather_code,is_day&hourly=temperature_2m,apparent_temperature,precipitation_probability,weather_code,relative_humidity_2m,wind_speed_10m${OM_TEMP_UNIT}${OM_WIND_UNIT}"
    log_debug "Constructed Open-Meteo Target URL: $forecast_url"

    if [[ "$VERBOSE" == "true" ]]; then
        log_debug "Executing curl payload fetch..."
        raw_api=$(curl -sS --connect-timeout 10 --max-time 30 "$forecast_url" 2>&1)
        curl_status=$?
        log_debug "Curl exit status code: $curl_status"
        if [ $curl_status -ne 0 ]; then
            log_debug "Network error during forecast download: $raw_api"
            raw_api=""
        elif echo "$raw_api" | jq -e '.error' >/dev/null 2>&1; then
            log_debug "Open-Meteo explicitly returned an API validation error: $(echo "$raw_api" | jq -c '.reason // .')"
            raw_api=""
        else
            log_debug "Successfully downloaded API payload. Payload size: ${#raw_api} bytes."
        fi
    else
        raw_api=$(curl -sf --connect-timeout 10 --max-time 30 "$forecast_url")
    fi
    
    if [ -z "$raw_api" ]; then
        log_debug "Raw API data is empty. Reverting to dummy data structures."
        if [ ! -f "$json_file" ]; then
            write_dummy_data
        fi
        return 1
    fi

    log_debug "Building layout date objects dynamically for jq injection..."
    dates_json="["
    for i in {0..4}; do
        future_date=$(date -d "+$i days" +%Y-%m-%d)
        f_day_raw=$(date -d "$future_date" "+%a")
        f_full_day_raw=$(date -d "$future_date" "+%A")
        f_m_raw=$(date -d "$future_date" "+%b")
        f_d_raw=$(date -d "$future_date" "+%d")

        f_day="$(t "weather.days.${f_day_raw,,}")"
        f_full_day="$(t "weather.days.${f_full_day_raw,,}")"
        f_month="$(t "weather.months.${f_m_raw,,}")"
        f_date_num="${f_d_raw} ${f_month}"

        dates_json="${dates_json}{\"day\":\"$f_day\",\"day_full\":\"$f_full_day\",\"date\":\"$f_date_num\"},"
    done
    dates_json="${dates_json%,}]"

    log_debug "Processing raw JSON arrays through context-safe compatibility layer..."
    
    i18n_json="$(get_weather_i18n_json)"

    jq_filter='
      def wmo_map(code; is_day):
        if code == 0 then
          if is_day == 1 then {icon: "", hex: "#f9e2af", desc: $i18n.sunny}
          else {icon: "", hex: "#cba6f7", desc: $i18n.clear} end
        elif code >= 1 and code <= 3 then {icon: "", hex: "#bac2de", desc: $i18n.cloudy}
        elif code == 45 or code == 48 then {icon: "󰖑", hex: "#84afdb", desc: $i18n.mist}
        elif (code >= 51 and code <= 57) or (code >= 61 and code <= 67) or (code >= 80 and code <= 82) then {icon: "󰖗", hex: "#74c7ec", desc: $i18n.rainy}
        elif (code >= 71 and code <= 77) or code == 85 or code == 86 then {icon: "", hex: "#cdd6f4", desc: $i18n.snow}
        elif code == 95 or code == 96 or code == 99 then {icon: "", hex: "#f9e2af", desc: $i18n.storm}
        else {icon: "", hex: "#cdd6f4", desc: $i18n.unknown} end;

      def fmt_t(t):
        if t == null then "0.0" else
          ((if $is_kelvin then t + 273.15 else t end * 10 | round) / 10) | tostring | 
          (if contains(".") then . else . + ".0" end)
        end;

      (.) as $root |
      ($root.current.weather_code) as $c_code |
      ($root.current.is_day) as $c_day |
      wmo_map($c_code; $c_day) as $c_map |

      (
        [
          range(0; $root.hourly.time | length) as $idx | {
            time_raw: $root.hourly.time[$idx],
            temp: $root.hourly.temperature_2m[$idx],
            feels_like: $root.hourly.apparent_temperature[$idx],
            pop: $root.hourly.precipitation_probability[$idx],
            humidity: $root.hourly.relative_humidity_2m[$idx],
            wind: $root.hourly.wind_speed_10m[$idx],
            code: $root.hourly.weather_code[$idx]
          }
        ] | group_by(.time_raw | split("T")[0]) | .[0:5] | 
        [
          range(0; length) as $day_idx | .[$day_idx] as $day_hours |
          
          ([$day_hours[].temp] | max) as $max_t |
          ([$day_hours[].temp] | min) as $min_t |
          ([$day_hours[].feels_like] | max) as $feels_t |
          ([$day_hours[].pop] | max) as $pop_max |
          ([$day_hours[].wind] | max | round) as $wind_max |
          (([$day_hours[].humidity] | add / length) | round) as $humidity_avg |
          
          ($day_hours[12].code // $day_hours[0].code) as $d_code |
          wmo_map($d_code; 1) as $d_map |
          
          [
            range(0; $day_hours | length) | select(. % 3 == 0) as $h_idx |
            $day_hours[$h_idx] |
            (.time_raw | split("T")[1]) as $t_str |
            ($t_str | split(":")[0] | tonumber) as $hour_num |
            (if $hour_num >= 6 and $hour_num <= 18 then 1 else 0 end) as $slot_day |
            wmo_map(.code; $slot_day) as $s_map |
            {
              time: $t_str,
              temp: fmt_t(.temp),
              icon: $s_map.icon,
              hex: $s_map.hex
            }
          ] as $hourly_slots |

          {
            id: ($day_idx | tostring),
            day: $dates[$day_idx].day,
            day_full: $dates[$day_idx].day_full,
            date: $dates[$day_idx].date,
            max: fmt_t($max_t),
            min: fmt_t($min_t),
            feels_like: fmt_t($feels_t),
            wind: ($wind_max | tostring),
            humidity: ($humidity_avg | tostring),
            pop: ($pop_max | tostring),
            icon: $d_map.icon,
            hex: $d_map.hex,
            desc: $d_map.desc,
            hourly: $hourly_slots
          }
        ]
      ) as $forecast |

      {
        latitude: ($lat | tonumber),
        longitude: ($lon | tonumber),
        location_updated_at: ($loc_ts | tonumber),
        unit: $unit,
        unit_sym: $unit_sym,
        current_temp: fmt_t($root.current.temperature_2m),
        current_temp_formatted: (fmt_t($root.current.temperature_2m) + $unit_sym),
        current_icon: $c_map.icon,
        current_hex: $c_map.hex,
        forecast: $forecast
      }
    '

    if [[ "$VERBOSE" == "true" ]]; then
        processed_json=$(echo "$raw_api" | jq --arg lat "$lat" --arg lon "$lon" --arg loc_ts "$loc_ts" --arg unit "$UNIT" --arg unit_sym "$UNIT_SYM" --argjson is_kelvin "$IS_KELVIN" --argjson dates "$dates_json" --argjson i18n "$i18n_json" "$jq_filter" 2>&1)
        jq_status=$?
        log_debug "jq computation exit status code: $jq_status"
        if [ $jq_status -ne 0 ]; then
            log_debug "jq compiler encountered an error processing data: $processed_json"
            processed_json=""
        fi
    else
        processed_json=$(echo "$raw_api" | jq --arg lat "$lat" --arg lon "$lon" --arg loc_ts "$loc_ts" --arg unit "$UNIT" --arg unit_sym "$UNIT_SYM" --argjson is_kelvin "$IS_KELVIN" --argjson dates "$dates_json" --argjson i18n "$i18n_json" "$jq_filter" 2>/dev/null)
    fi

    if [ ! -z "$processed_json" ]; then
        log_debug "Successfully completed dataset restructuring. Committing payload to disk: $json_file"
        echo "$processed_json" > "${json_file}"
    else
        log_debug "Data filtering phase returned an empty payload. Retaining dummy block."
        return 1
    fi
}

if [[ "$ACTION" == "--getdata" ]]; then
    get_data

elif [[ "$ACTION" == "--json" ]]; then
    CACHE_LIMIT=900
    PENDING_RETRY_LIMIT=3600

    loc_json=$(get_location)
    cur_lat=$(echo "$loc_json" | jq -r '.latitude // empty' 2>/dev/null)
    cur_lon=$(echo "$loc_json" | jq -r '.longitude // empty' 2>/dev/null)
    cur_loc_updated=$(echo "$loc_json" | jq -r '.updated_at // 0' 2>/dev/null)

    [[ -z "$cur_lat" || "$cur_lat" == "null" ]] && cur_lat="0.0"
    [[ -z "$cur_lon" || "$cur_lon" == "null" ]] && cur_lon="0.0"
    [[ -z "$cur_loc_updated" || "$cur_loc_updated" == "null" ]] && cur_loc_updated=0

    if [ -f "$json_file" ]; then
        cached_unit=$(jq -r '.unit // empty' "$json_file" 2>/dev/null)
        cached_loc_updated=$(jq -r '.location_updated_at // 0' "$json_file" 2>/dev/null)
        cached_lat=$(jq -r '.latitude // empty' "$json_file" 2>/dev/null)
        cached_lon=$(jq -r '.longitude // empty' "$json_file" 2>/dev/null)

        if [[ "$cached_unit" != "$UNIT" || "$cached_loc_updated" != "$cur_loc_updated" || "$cached_lat" != "$cur_lat" || "$cached_lon" != "$cur_lon" ]]; then
            log_debug "Location or unit mismatch. Refreshing immediately..."
            get_data
            cat "$json_file"
            exit 0
        fi

        file_time=$(stat -c %Y "$json_file")
        current_time=$(date +%s)
        diff=$((current_time - file_time))
        log_debug "JSON cache file age: $diff seconds (Limit: $CACHE_LIMIT)"
        offline_desc="$(t "weather.desc.offline")"
        if grep -q "\"desc\": \"${offline_desc}\"" "$json_file"; then
            log_debug "Cache contains offline dummy data. Retry limit check: $diff vs $PENDING_RETRY_LIMIT"
            if [ $diff -gt $PENDING_RETRY_LIMIT ]; then
                log_debug "Wiping and updating background cache due to stale offline marker."
                touch "$json_file"
                get_data &
            fi
        else
            if [ $diff -gt $CACHE_LIMIT ]; then
                log_debug "Cache exceeded normal limit. Launching background fetch..."
                touch "$json_file"
                get_data &
            fi
        fi
        cat "$json_file"
    else
        log_debug "Cache file not found. Running foreground get_data..."
        get_data
        cat "$json_file"
    fi

elif [[ "$ACTION" == "--view-listener" ]]; then
    if [ ! -f "$view_file" ]; then echo "0" > "$view_file"; fi
    tail -F "$view_file"

elif [[ "$ACTION" == "--nav" ]]; then
    if [ ! -f "$view_file" ]; then echo "0" > "$view_file"; fi
    current=$(cat "$view_file")
    direction="$DIRECTION"
    max_idx=4
    if [[ "$direction" == "next" ]]; then
        if [ "$current" -lt "$max_idx" ]; then
            new=$((current + 1))
            echo "$new" > "$view_file"
        fi
    elif [[ "$direction" == "prev" ]]; then
        if [ "$current" -gt 0 ]; then
            new=$((current - 1))
            echo "$new" > "$view_file"
        fi
    fi

elif [[ "$ACTION" == "--icon" ]]; then
    cat "$json_file" | jq -r '.forecast[0].icon'

elif [[ "$ACTION" == "--temp" ]]; then 
    t=$(cat "$json_file" | jq -r '.forecast[0].max' 2>/dev/null)
    echo "${t:-0.0}${UNIT_SYM}"

elif [[ "$ACTION" == "--hex" ]]; then 
    cat "$json_file" | jq -r '.forecast[0].hex'

elif [[ "$ACTION" == "--current-icon" ]]; then
    icon=$(cat "$json_file" | jq -r '.current_icon // empty' 2>/dev/null)
    if [[ -z "$icon" || "$icon" == "null" ]]; then 
        get_data
        icon=$(cat "$json_file" | jq -r '.current_icon')
    fi
    echo "$icon"

elif [[ "$ACTION" == "--current-temp" ]]; then 
    t=$(cat "$json_file" | jq -r '.current_temp // empty' 2>/dev/null)
    if [[ -z "$t" || "$t" == "null" ]]; then 
        get_data
        t=$(cat "$json_file" | jq -r '.current_temp')
    fi
    echo "${t}${UNIT_SYM}"

elif [[ "$ACTION" == "--current-hex" ]]; then
    hex=$(cat "$json_file" | jq -r '.current_hex // empty' 2>/dev/null)
    if [[ -z "$hex" || "$hex" == "null" ]]; then 
        get_data
        hex=$(cat "$json_file" | jq -r '.current_hex')
    fi
    echo "$hex"
fi
