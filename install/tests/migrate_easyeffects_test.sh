#!/usr/bin/env bash

set -u

REPO_ROOT="$(dirname "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")")"
SCRIPT="$REPO_ROOT/src/scripts/migrate_easyeffects.sh"
SANDBOX="$(mktemp -d)"
PIDS="$SANDBOX/pids"
CALLS="$SANDBOX/calls.log"
OUT="$SANDBOX/out.log"
ACTIVE="$SANDBOX/active-units"
ENABLED="$SANDBOX/enabled-units"
STUBS="$SANDBOX/stubs"
TOOLS="$SANDBOX/tools"
FAKE_EE="$SANDBOX/fakebin/easyeffects"
REAL_PGREP="$(command -v pgrep)"

cleanup() {
    local pid
    while read -r pid; do
        [ -n "$pid" ] && kill -KILL "$pid" 2>/dev/null
    done < "$PIDS"
    rm -rf "$SANDBOX"
}
: > "$PIDS"
trap cleanup EXIT

failures=0
check() {
    if eval "$2"; then
        echo "ok    $1"
    else
        echo "FAIL  $1"
        failures=$((failures + 1))
    fi
}

mkdir -p "$STUBS" "$TOOLS" "$(dirname "$FAKE_EE")"
for tool in bash cat cp sed grep mkdir rmdir rm mv sleep seq dirname realpath id jq touch ln chmod readlink xargs tr cut head awk wc basename env date; do
    path="$(command -v "$tool")" && ln -s "$path" "$TOOLS/$tool"
done

stub() {
    printf '#!/usr/bin/env bash\n%s\n' "$2" > "$STUBS/$1"
    chmod +x "$STUBS/$1"
}
stub pgrep "\"$REAL_PGREP\" \"\$@\" | grep -Fxf \"$PIDS\""
stub systemctl "echo \"systemctl \$*\" >> \"$CALLS\"
unit=\"\${*: -1}\"
case \"\$2\" in
    is-active) grep -qxF \"\$unit\" \"$ACTIVE\" ;;
    is-enabled) if grep -qxF \"\$unit\" \"$ENABLED\"; then echo enabled; else echo disabled; exit 1; fi ;;
esac"
stub busctl 'echo "b true"'
stub notify-send "echo \"notify-send \$*\" >> \"$CALLS\""
printf '#!/usr/bin/env bash\nwhile :; do sleep 0.2; done\n' > "$FAKE_EE"

export PATH="$STUBS:$TOOLS"
export LANG=C
unset LC_ALL LC_MESSAGES
export SERPANTINUM_DIR="$REPO_ROOT/src"
export XDG_RUNTIME_DIR="$SANDBOX/run"
mkdir -p "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

reset_home() {
    export HOME="$SANDBOX/home-$1"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$HOME/.local/share"
    MARKER="$HOME/.local/state/serpantinum/easyeffects-migrated"
    PRESETS="$XDG_DATA_HOME/easyeffects/output"
    mkdir -p "$HOME"
    : > "$CALLS"
    : > "$ACTIVE"
    : > "$ENABLED"
}

spawn_easyeffects() {
    ( bash "$FAKE_EE" "$@" >/dev/null 2>&1 & echo "$!" >> "$PIDS"; echo "$!" > "$SANDBOX/last-pid" )
    cat "$SANDBOX/last-pid"
}

alive() {
    [ -r "/proc/$1/stat" ] && awk '{ exit ($3 == "Z") }' "/proc/$1/stat"
}

run_migration() {
    bash "$SCRIPT" > "$OUT" 2>&1
}

write_shipped_autostart() {
    local base="$1"
    mkdir -p "$base/hypr/config" "$base/niri/config" "$base/sway/configDir" "$base/mango/config"
    cat > "$base/hypr/config/autostart.lua" <<'EOF'
hl.on("hyprland.start", function()
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("systemctl --user enable --now easyeffects")
  hl.exec_cmd("serpantinumd start")
end)
EOF
    printf 'spawn-at-startup "bash" "-c" "wl-paste --type text --watch cliphist store"\nspawn-at-startup "systemctl" "--user" "enable" "--now" "easyeffects"\nspawn-at-startup "serpantinumd" "start"\n' > "$base/niri/config/autostart.kdl"
    printf 'exec wl-paste --type text --watch cliphist store\nexec systemctl --user enable --now easyeffects\nexec serpantinumd start\n' > "$base/sway/configDir/autostart"
    printf 'exec_once=wl-paste --type text --watch cliphist store\nexec_once=systemctl --user enable --now easyeffects\nexec_once=serpantinumd start\n' > "$base/mango/config/autostart.conf"
}

SHIPPED=(hypr/config/autostart.lua niri/config/autostart.kdl sway/configDir/autostart mango/config/autostart.conf)

echo "== without the audio engine"
reset_home no-engine
write_shipped_autostart "$XDG_CONFIG_HOME"
mkdir -p "$PRESETS"
echo '{}' > "$PRESETS/live_eq.json"
own_pid="$(spawn_easyeffects -w -l live_eq)"
SERPANTINUM_INSTALLER=1 run_migration
check "nothing is touched" "[ ! -s '$CALLS' ] && [ ! -f '$MARKER' ] && [ -f '$PRESETS/live_eq.json' ] && grep -q easyeffects '$XDG_CONFIG_HOME/sway/configDir/autostart'"
check "its EasyEffects keeps running" "alive $own_pid"
kill -KILL "$own_pid" 2>/dev/null

stub serpantinum-audio 'exit 0'

echo "== a user updating from the EasyEffects equalizer"
reset_home update
write_shipped_autostart "$XDG_CONFIG_HOME"
printf '  hl.exec_cmd("systemctl --user enable --now easyeffects")\n' > "$XDG_CONFIG_HOME/hypr/config/mine.lua"
mkdir -p "$PRESETS" "$XDG_CONFIG_HOME/systemd/user" "$XDG_CONFIG_HOME/autostart"
echo '{}' > "$PRESETS/live_eq.json"
echo '{}' > "$PRESETS/my_own_preset.json"
printf '[Service]\nExecStart=easyeffects --gapplication-service\n' > "$XDG_CONFIG_HOME/systemd/user/easyeffects.service"
printf '[Service]\nExecStart=easyeffects -w -l live_eq\n' > "$XDG_CONFIG_HOME/systemd/user/ee-eq.service"
printf '[Desktop Entry]\n' > "$XDG_CONFIG_HOME/autostart/com.github.wwmm.easyeffects.desktop"
echo ee-eq.service > "$ACTIVE"
own_pid="$(spawn_easyeffects -w -l live_eq)"
user_pid="$(spawn_easyeffects --hide-window)"
SERPANTINUM_INSTALLER=1 run_migration
check "exit status is zero" "[ $? -eq 0 ]"
check "the instance the old equalizer started is stopped" "! alive $own_pid"
check "an EasyEffects the user started keeps running" "alive $user_pid"
check "a running ee-eq unit is stopped for the session" "grep -q 'systemctl --user stop ee-eq.service' '$CALLS'"
check "no unit is disabled" "! grep -q disable '$CALLS'"
check "the user's unit files are kept" "[ -f '$XDG_CONFIG_HOME/systemd/user/easyeffects.service' ] && [ -f '$XDG_CONFIG_HOME/systemd/user/ee-eq.service' ]"
check "the XDG autostart entry is kept" "[ -f '$XDG_CONFIG_HOME/autostart/com.github.wwmm.easyeffects.desktop' ]"
check "the generated preset is removed" "[ ! -e '$PRESETS/live_eq.json' ]"
check "the user's own presets are kept" "[ -f '$PRESETS/my_own_preset.json' ]"
for f in "${SHIPPED[@]}"; do
    check "$f: line removed" "! grep -q easyeffects '$XDG_CONFIG_HOME/$f'"
    check "$f: other lines kept" "grep -q 'serpantinumd' '$XDG_CONFIG_HOME/$f' && grep -q cliphist '$XDG_CONFIG_HOME/$f'"
    check "$f: backup written" "grep -q easyeffects '$XDG_CONFIG_HOME/$f.pre-audio-engine.bak'"
done
check "the same line in a file Serpantinum did not ship is kept" "grep -q easyeffects '$XDG_CONFIG_HOME/hypr/config/mine.lua'"
check "the installer prints the notice" "grep -q 'EasyEffects is still enabled' '$OUT'"
check "a completion marker is written" "[ -f '$MARKER' ]"
: > "$CALLS"
SERPANTINUM_INSTALLER=1 run_migration
check "a second run does nothing" "[ ! -s '$CALLS' ] && [ ! -s '$OUT' ]"
kill -KILL "$user_pid" 2>/dev/null

echo "== configs managed through links"
reset_home links
write_shipped_autostart "$SANDBOX/dotfiles"
mkdir -p "$XDG_CONFIG_HOME/mango/config"
ln -s "$SANDBOX/dotfiles/mango/config/autostart.conf" "$XDG_CONFIG_HOME/mango/config/autostart.conf"
ln -s "$SANDBOX/dotfiles/sway" "$XDG_CONFIG_HOME/sway"
SERPANTINUM_INSTALLER=1 run_migration
check "a symlinked autostart file is not edited" "grep -q easyeffects '$SANDBOX/dotfiles/mango/config/autostart.conf' && [ ! -e '$SANDBOX/dotfiles/mango/config/autostart.conf.pre-audio-engine.bak' ]"
check "a file inside a symlinked folder is not edited" "grep -q easyeffects '$SANDBOX/dotfiles/sway/configDir/autostart' && [ ! -e '$SANDBOX/dotfiles/sway/configDir/autostart.pre-audio-engine.bak' ]"
check "nothing Serpantinum did here, so no notice" "[ ! -s '$OUT' ]"

echo "== a new user with their own EasyEffects"
reset_home fresh
mkdir -p "$PRESETS" "$XDG_CONFIG_HOME/autostart"
echo '{}' > "$PRESETS/my_own_preset.json"
printf '[Desktop Entry]\n' > "$XDG_CONFIG_HOME/autostart/com.github.wwmm.easyeffects.desktop"
echo easyeffects.service > "$ENABLED"
user_pid="$(spawn_easyeffects --hide-window)"
SERPANTINUM_INSTALLER=1 run_migration
check "their EasyEffects keeps running" "alive $user_pid"
check "their setup is untouched" "[ -f '$XDG_CONFIG_HOME/autostart/com.github.wwmm.easyeffects.desktop' ] && [ -f '$PRESETS/my_own_preset.json' ] && ! grep -qE 'stop|disable' '$CALLS'"
check "they get no notice" "[ ! -s '$OUT' ]"
check "the marker is still written" "[ -f '$MARKER' ]"
kill -KILL "$user_pid" 2>/dev/null

echo "== first shell start after a package update"
reset_home package
mkdir -p "$PRESETS"
echo '{}' > "$PRESETS/live_eq.json"
echo easyeffects.service > "$ENABLED"
run_migration
check "the preset folder Serpantinum created is removed once empty" "[ ! -e '$PRESETS' ] && [ ! -e '$XDG_DATA_HOME/easyeffects' ]"
check "nothing is printed outside the installer" "[ ! -s '$OUT' ]"
for _ in $(seq 50); do
    grep -q notify-send "$CALLS" && break
    sleep 0.1
done
check "the notice is sent as a notification" "grep -q 'notify-send -a Serpantinum EasyEffects is still enabled' '$CALLS'"

echo "$([ "$failures" -eq 0 ] && echo 'all passed' || echo "$failures FAILED")"
[ "$failures" -eq 0 ]
