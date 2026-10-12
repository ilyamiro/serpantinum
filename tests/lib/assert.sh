#!/usr/bin/env bash

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

assert_eq() {
    local expected="$1" actual="$2" msg="${3:-}"
    [[ "$expected" == "$actual" ]] || fail "${msg:+$msg: }expected '$expected', got '$actual'"
}

# Asserts that a newline-separated list contains the given line.
assert_contains_line() {
    local haystack="$1" needle="$2"
    grep -qxF -- "$needle" <<< "$haystack" || fail "expected line '$needle' in:"$'\n'"$haystack"
}

assert_not_contains_line() {
    local haystack="$1" needle="$2"
    ! grep -qxF -- "$needle" <<< "$haystack" || fail "unexpected line '$needle' in:"$'\n'"$haystack"
}

assert_empty() {
    [[ -z "$1" ]] || fail "expected empty output, got:"$'\n'"$1"
}

# Asserts how many times an exact line occurs.
assert_line_count() {
    local haystack="$1" needle="$2" expected="$3"
    local count
    count=$(grep -cxF -- "$needle" <<< "$haystack")
    assert_eq "$expected" "$count" "occurrences of '$needle'"
}
