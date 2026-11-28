#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

assert_eq() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        PASS=$((PASS + 1))
    else
        echo "FAIL: $label (expected='$expected', actual='$actual')"
        FAIL=$((FAIL + 1))
    fi
}

assert_ok() {
    local label="$1"
    shift
    if "$@"; then
        PASS=$((PASS + 1))
    else
        echo "FAIL: $label (command failed: $*)"
        FAIL=$((FAIL + 1))
    fi
}

assert_fail() {
    local label="$1"
    shift
    if "$@"; then
        echo "FAIL: $label (expected failure, got success: $*)"
        FAIL=$((FAIL + 1))
    else
        PASS=$((PASS + 1))
    fi
}

assert_contains() {
    local label="$1" needle="$2" haystack="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        PASS=$((PASS + 1))
    else
        echo "FAIL: $label (missing '$needle' in '$haystack')"
        FAIL=$((FAIL + 1))
    fi
}

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

TOOLS_BIN="$TMP_ROOT/tools"
mkdir -p "$TOOLS_BIN"
for tool in bash cat sed grep mkdir rm mv dirname realpath id jq tr cut head awk env uname tee printf test touch chmod sleep setsid xargs whoami; do
    if path="$(command -v "$tool" 2>/dev/null)"; then
        ln -sf "$path" "$TOOLS_BIN/$tool"
    fi
done

source "$REPO_ROOT/install/modules/os_release.sh"

cat > "$TMP_ROOT/single-quoted" <<'EOF'
# comment line
NAME='Gentoo'
ID='gentoo'
PRETTY_NAME='Gentoo Linux'
EOF

assert_eq "single-quoted ID" "gentoo" "$(os_release_get ID "$TMP_ROOT/single-quoted")"
assert_eq "single-quoted PRETTY_NAME" "Gentoo Linux" "$(os_release_get PRETTY_NAME "$TMP_ROOT/single-quoted")"
assert_eq "missing optional ID_LIKE returns empty" "" "$(os_release_get ID_LIKE "$TMP_ROOT/single-quoted")"

cat > "$TMP_ROOT/complex" <<'EOF'
  # indented comment
  ID="arch"
ID='gentoo'
ID_LIKE="gentoo  funtoo"
PRETTY_NAME="Gentoo \"Custom\" \\ \$ \` = 1"
SINGLE_ESC='keep \" literal'
CRLF_FIELD='hello'
EMPTY_DQ=""
EMPTY_SQ=''
SINGLE_CHAR="
EOF
printf 'CRLF_KEY='\''crlf-val'\''\r\n' >> "$TMP_ROOT/complex"

assert_eq "last assignment wins for duplicate ID" "gentoo" "$(os_release_get ID "$TMP_ROOT/complex")"
assert_eq "double-quoted escapes and equals sign" 'Gentoo "Custom" \ $ ` = 1' "$(os_release_get PRETTY_NAME "$TMP_ROOT/complex")"
assert_eq "single quotes preserve backslashes literally" 'keep \" literal' "$(os_release_get SINGLE_ESC "$TMP_ROOT/complex")"
assert_eq "CRLF line ending stripped" "crlf-val" "$(os_release_get CRLF_KEY "$TMP_ROOT/complex")"
assert_eq "empty double-quoted value" "" "$(os_release_get EMPTY_DQ "$TMP_ROOT/complex")"
assert_eq "empty single-quoted value" "" "$(os_release_get EMPTY_SQ "$TMP_ROOT/complex")"
assert_eq "unmatched single quote char does not crash" '"' "$(os_release_get SINGLE_CHAR "$TMP_ROOT/complex")"
assert_fail "missing file returns failure" os_release_get ID "$TMP_ROOT/does-not-exist"

cat > "$TMP_ROOT/no-newline" <<'EOF'
ID='gentoo'
EOF
tr -d '\n' < "$TMP_ROOT/no-newline" > "$TMP_ROOT/no-newline-trimmed"
assert_eq "file without trailing newline" "gentoo" "$(os_release_get ID "$TMP_ROOT/no-newline-trimmed")"

PM_BIN="$TMP_ROOT/pm_bin"
mkdir -p "$PM_BIN"
for cmd in emerge dnf xbps-install pacman; do
    printf '#!/usr/bin/env bash\nexit 0\n' > "$PM_BIN/$cmd"
    chmod +x "$PM_BIN/$cmd"
done

assert_eq "detect_package_manager with single-quoted gentoo even when pacman exists" "portage" "$(
    PATH="$PM_BIN:$TOOLS_BIN" OS_RELEASE_FILE="$TMP_ROOT/single-quoted" bash -c '
        source "'"$REPO_ROOT"'/install/modules/pm.sh"
        echo "$PM_NAME"
    '
)"

cat > "$TMP_ROOT/fedora-sq" <<'EOF'
NAME='Fedora Linux'
ID='fedora'
PRETTY_NAME='Fedora Linux 42'
EOF
assert_eq "detect_package_manager with single-quoted fedora even when pacman exists" "dnf" "$(
    PATH="$PM_BIN:$TOOLS_BIN" OS_RELEASE_FILE="$TMP_ROOT/fedora-sq" bash -c '
        source "'"$REPO_ROOT"'/install/modules/pm.sh"
        echo "$PM_NAME"
    '
)"

cat > "$TMP_ROOT/void-sq" <<'EOF'
NAME='Void'
ID='void'
PRETTY_NAME='Void Linux'
EOF
assert_eq "detect_package_manager with single-quoted void even when pacman exists" "void" "$(
    PATH="$PM_BIN:$TOOLS_BIN" OS_RELEASE_FILE="$TMP_ROOT/void-sq" bash -c '
        source "'"$REPO_ROOT"'/install/modules/pm.sh"
        echo "$PM_NAME"
    '
)"

cat > "$TMP_ROOT/nobara-sq" <<'EOF'
ID='nobara'
ID_LIKE='fedora'
EOF
cat > "$TMP_ROOT/rocky-sq" <<'EOF'
ID='rocky'
ID_LIKE='rhel centos fedora'
EOF
cat > "$TMP_ROOT/calc-sq" <<'EOF'
ID='calculate'
ID_LIKE='gentoo'
EOF
cat > "$TMP_ROOT/arch-sq" <<'EOF'
ID='Arch'
PRETTY_NAME='Arch Linux'
EOF
cat > "$TMP_ROOT/ubuntu-sq" <<'EOF'
ID='ubuntu'
ID_LIKE='debian'
PRETTY_NAME='Ubuntu'
EOF

assert_ok "portage pm_supports_os standalone with single-quoted gentoo" env PATH="$PM_BIN:$TOOLS_BIN" OS_RELEASE_FILE="$TMP_ROOT/single-quoted" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_supports_os
'
assert_ok "portage pm_supports_os standalone with single-quoted calculate" env PATH="$PM_BIN:$TOOLS_BIN" OS_RELEASE_FILE="$TMP_ROOT/calc-sq" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/portage.sh"
    pm_supports_os
'
assert_ok "dnf pm_supports_os standalone with single-quoted fedora" env PATH="$PM_BIN:$TOOLS_BIN" OS_RELEASE_FILE="$TMP_ROOT/fedora-sq" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/dnf.sh"
    pm_supports_os
'
assert_ok "dnf pm_supports_os standalone with single-quoted nobara" env PATH="$PM_BIN:$TOOLS_BIN" OS_RELEASE_FILE="$TMP_ROOT/nobara-sq" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/dnf.sh"
    pm_supports_os
'
assert_fail "dnf pm_supports_os rejects single-quoted rocky" env PATH="$PM_BIN:$TOOLS_BIN" OS_RELEASE_FILE="$TMP_ROOT/rocky-sq" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/dnf.sh"
    pm_supports_os
'
assert_ok "void pm_supports_os standalone with single-quoted void" env PATH="$PM_BIN:$TOOLS_BIN" OS_RELEASE_FILE="$TMP_ROOT/void-sq" bash -c '
    source "'"$REPO_ROOT"'/install/modules/pm/void.sh"
    pm_supports_os
'

assert_ok "check_supported_os succeeds on single-quoted Gentoo under set -e" env \
    PATH="$PM_BIN:$TOOLS_BIN" OS_RELEASE_FILE="$TMP_ROOT/single-quoted" \
    I18N_DIR="$REPO_ROOT/src/assets/languages" SERPANTINUM_DIR="$REPO_ROOT/src" LANG="en_US.UTF-8" \
    bash -e -c '
        source "'"$REPO_ROOT"'/src/scripts/i18n.sh"
        source "'"$REPO_ROOT"'/install/modules/pm.sh"
        source "'"$REPO_ROOT"'/install/modules/deps.sh"
        check_supported_os
    '

assert_ok "check_supported_os succeeds on single-quoted mixed-case Arch under set -e" env \
    PATH="$PM_BIN:$TOOLS_BIN" OS_RELEASE_FILE="$TMP_ROOT/arch-sq" \
    I18N_DIR="$REPO_ROOT/src/assets/languages" SERPANTINUM_DIR="$REPO_ROOT/src" LANG="en_US.UTF-8" \
    bash -e -c '
        source "'"$REPO_ROOT"'/src/scripts/i18n.sh"
        source "'"$REPO_ROOT"'/install/modules/pm.sh"
        source "'"$REPO_ROOT"'/install/modules/deps.sh"
        check_supported_os
    '

UNSUP_OUT="$(
    PATH="$PM_BIN:$TOOLS_BIN" OS_RELEASE_FILE="$TMP_ROOT/ubuntu-sq" \
    I18N_DIR="$REPO_ROOT/src/assets/languages" SERPANTINUM_DIR="$REPO_ROOT/src" LANG="en_US.UTF-8" \
    bash -c '
        source "'"$REPO_ROOT"'/src/scripts/i18n.sh"
        source "'"$REPO_ROOT"'/install/modules/pm.sh"
        source "'"$REPO_ROOT"'/install/modules/deps.sh"
        check_supported_os
    ' 2>&1 || true
)"
assert_contains "unsupported OS error strips single quotes from ID" "Unsupported OS (ubuntu)." "$UNSUP_OUT"
assert_contains "unsupported OS error lists Arch Linux, Fedora, Void Linux, Gentoo" "Arch Linux, Fedora, Void Linux, Gentoo" "$UNSUP_OUT"

UI_OS="$(
    PATH="$PM_BIN:$TOOLS_BIN" OS_RELEASE_FILE="$TMP_ROOT/single-quoted" \
    I18N_DIR="$REPO_ROOT/src/assets/languages" SERPANTINUM_DIR="$REPO_ROOT/src" LANG="en_US.UTF-8" \
    bash -e -c '
        source "'"$REPO_ROOT"'/src/scripts/i18n.sh"
        source "'"$REPO_ROOT"'/install/modules/pm.sh"
        source "'"$REPO_ROOT"'/install/modules/ui.sh"
        trap - EXIT INT TERM
        printf "%s\n" "$OS_NAME"
    '
)"
assert_eq "ui.sh parses single-quoted PRETTY_NAME" "Gentoo Linux" "$UI_OS"

cat > "$TMP_ROOT/name-only" <<'EOF'
ID='gentoo'
NAME='Gentoo'
EOF
UI_OS_FALLBACK="$(
    PATH="$PM_BIN:$TOOLS_BIN" OS_RELEASE_FILE="$TMP_ROOT/name-only" \
    I18N_DIR="$REPO_ROOT/src/assets/languages" SERPANTINUM_DIR="$REPO_ROOT/src" LANG="en_US.UTF-8" \
    bash -e -c '
        source "'"$REPO_ROOT"'/src/scripts/i18n.sh"
        source "'"$REPO_ROOT"'/install/modules/pm.sh"
        source "'"$REPO_ROOT"'/install/modules/ui.sh"
        trap - EXIT INT TERM
        printf "%s\n" "$OS_NAME"
    '
)"
assert_eq "ui.sh falls back to single-quoted NAME" "Gentoo" "$UI_OS_FALLBACK"

TEL_BIN="$TMP_ROOT/tel_bin"
mkdir -p "$TEL_BIN"
TEL_PAYLOAD="$TMP_ROOT/tel_payload.json"
cat > "$TEL_BIN/curl" <<'EOF'
#!/usr/bin/env bash
while [[ "$#" -gt 0 ]]; do
    if [[ "$1" == "-d" ]]; then
        printf '%s' "$2" > "$MOCK_PAYLOAD_FILE"
        exit 0
    fi
    shift
done
EOF
chmod +x "$TEL_BIN/curl"

PATH="$TEL_BIN:$PATH" MOCK_PAYLOAD_FILE="$TEL_PAYLOAD" OS_RELEASE_FILE="$TMP_ROOT/single-quoted" \
    bash "$REPO_ROOT/install/modules/telemetry.sh" \
    --mode init --version "2.5.4" --id "1033a555-8580-43ba-893a-07abbb58f633" --enabled true
for _ in 1 2 3 4 5 6 7 8 9 10; do
    [ -s "$TEL_PAYLOAD" ] && break
    sleep 0.05
done
assert_eq "telemetry.sh parses single-quoted PRETTY_NAME" "Gentoo Linux" "$(jq -r '.os' "$TEL_PAYLOAD")"

rm -f "$TEL_PAYLOAD"
PATH="$TEL_BIN:$PATH" MOCK_PAYLOAD_FILE="$TEL_PAYLOAD" OS_RELEASE_FILE="$TMP_ROOT/fedora-sq" \
    bash "$REPO_ROOT/install/modules/telemetry.sh" \
    --mode init --version "2.5.4" --id "1033a555-8580-43ba-893a-07abbb58f633" --enabled true
sleep 0.2
assert_fail "telemetry.sh skips single-quoted Fedora" test -s "$TEL_PAYLOAD"

BOOT_BIN="$TMP_ROOT/boot_bin"
mkdir -p "$BOOT_BIN"
BOOT_LOG="$TMP_ROOT/boot.log"
cat > "$BOOT_BIN/sudo" <<'EOF'
#!/usr/bin/env bash
echo "$*" >> "$BOOT_LOG"
if [[ "$1" == "emerge" ]]; then
    exit 99
fi
exit 98
EOF
cat > "$BOOT_BIN/emerge" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$BOOT_BIN/pacman" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$BOOT_BIN/sudo" "$BOOT_BIN/emerge" "$BOOT_BIN/pacman"

cp "$REPO_ROOT/install/install.sh" "$TMP_ROOT/standalone-install.sh"
: > "$BOOT_LOG"
set +e
PATH="$BOOT_BIN:$TOOLS_BIN" BOOT_LOG="$BOOT_LOG" OS_RELEASE_FILE="$TMP_ROOT/single-quoted" \
    bash "$TMP_ROOT/standalone-install.sh" >/dev/null 2>&1
BOOT_RC=$?
set -e
assert_eq "install.sh bootstrap selects emerge on single-quoted Gentoo even when pacman exists" "99" "$BOOT_RC"
assert_contains "install.sh bootstrap invokes emerge for git" "emerge --ask=n --noreplace --quiet-build=y dev-vcs/git" "$(cat "$BOOT_LOG")"

echo "Passed: $PASS, Failed: $FAIL"
[ "$FAIL" -eq 0 ]
