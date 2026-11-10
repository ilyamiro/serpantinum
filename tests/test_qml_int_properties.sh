#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo "=== Checking QML integer properties ==="
echo "Scanning for invalid decimal assignments to font.pixelSize in src/quickshell/..."

MATCHES=$(grep -rnE 'font\.pixelSize[[:space:]]*:[[:space:]]*[0-9]+\.[0-9]+' --include="*.qml" src/quickshell/ || true)

if [ -n "$MATCHES" ]; then
    echo "ERROR: Invalid decimal font.pixelSize assignments found:"
    echo "$MATCHES"
    exit 1
fi

echo "PASS: No invalid decimal font.pixelSize assignments found."

echo ""
echo "=== Running qmllint syntax and property validation ==="
FILES_TO_LINT=(
    "src/quickshell/widgets/faces/tasks/TasksFace.qml"
    "src/quickshell/widgets/WidgetRegistry.qml"
)

if command -v qmllint >/dev/null 2>&1; then
    for file in "${FILES_TO_LINT[@]}"; do
        if [ ! -f "$file" ]; then
            echo "ERROR: File $file not found for qmllint validation."
            exit 1
        fi
    done

    echo "Running: qmllint ${FILES_TO_LINT[*]}"
    if ! qmllint "${FILES_TO_LINT[@]}"; then
        echo "ERROR: qmllint reported errors in one or more files."
        exit 1
    fi
    echo "PASS: qmllint validation passed for all target files."
else
    echo "WARNING: qmllint command not found in PATH, skipping qmllint check."
fi

echo ""
echo "All QML integer property checks passed successfully."
exit 0
