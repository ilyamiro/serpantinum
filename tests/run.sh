#!/usr/bin/env bash
# Minimal dependency-free test runner.
# Usage: tests/run.sh [tests/test_foo.sh ...]
# Every function named test_* in a test file runs in its own subshell; the
# optional setup function of the file runs before each test.

TESTS_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
PROJECT_ROOT="$(dirname "$TESTS_DIR")"
FIXTURES_DIR="$TESTS_DIR/fixtures"
export TESTS_DIR PROJECT_ROOT FIXTURES_DIR

source "$TESTS_DIR/lib/assert.sh"

files=("$@")
[[ ${#files[@]} -eq 0 ]] && files=("$TESTS_DIR"/test_*.sh)

passed=0
failed=0
failed_names=()

for file in "${files[@]}"; do
    echo -e "\e[1m$(basename "$file")\e[0m"
    tests=$(bash -c "source '$TESTS_DIR/lib/assert.sh'; source '$file'; declare -F" | awk '$3 ~ /^test_/ {print $3}')

    for name in $tests; do
        TEST_TMP=$(mktemp -d)
        output=$(
            # Tests must never wait for keyboard input.
            exec < /dev/null
            export TEST_TMP
            source "$file"
            declare -F setup &>/dev/null && setup
            "$name"
        2>&1)
        status=$?
        rm -rf "$TEST_TMP"

        if [[ $status -eq 0 ]]; then
            passed=$((passed + 1))
            echo -e "  \e[32m✔\e[0m $name"
        else
            failed=$((failed + 1))
            failed_names+=("$(basename "$file"): $name")
            echo -e "  \e[31m✘\e[0m $name"
            [[ -n "$output" ]] && sed 's/^/      /' <<< "$output"
        fi
    done
done

echo
echo -e "\e[1m$passed passed, $failed failed\e[0m"
for name in "${failed_names[@]}"; do
    echo -e "  \e[31m✘\e[0m $name"
done

[[ $failed -eq 0 ]]
