#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

TARGET_FILE="src/quickshell/widgets/WidgetRegistry.qml"

echo "=== Checking WidgetRegistry.qml normalization ==="

if [ ! -f "$TARGET_FILE" ]; then
    echo "ERROR: Target file $TARGET_FILE does not exist."
    exit 1
fi

FUNCTIONS=(
    "faceFile"
    "faceComponent"
    "variantList"
    "defaultVariant"
    "defaultSize"
    "additionalSettings"
)

ERRORS=0

for fn in "${FUNCTIONS[@]}"; do
    BODY=$(awk -v fn="$fn" '
      $0 ~ "function[[:space:]]+" fn "[[:space:]]*\\(" {
        found = 1
        depth = 0
        body = ""
      }
      found {
        body = body "\n" $0
        for (i = 1; i <= length($0); i++) {
          c = substr($0, i, 1)
          if (c == "{") depth++
          if (c == "}") depth--
        }
        if (depth <= 0 && body ~ /{/) {
          found = 0
          print body
        }
      }
    ' "$TARGET_FILE")

    if [ -z "$BODY" ]; then
        echo "FAIL: Function '$fn' was not found in $TARGET_FILE"
        ERRORS=$((ERRORS + 1))
        continue
    fi

    has_scrum=$(echo "$BODY" | grep -c '"scrum"' || true)
    has_todos=$(echo "$BODY" | grep -c '"todos"' || true)
    has_tasks=$(echo "$BODY" | grep -c '"tasks"' || true)

    if [ "$has_scrum" -eq 0 ] || [ "$has_todos" -eq 0 ] || [ "$has_tasks" -eq 0 ]; then
        echo "FAIL: Function '$fn' is missing normalization mapping 'scrum' and 'todos' to 'tasks'."
        echo "      Presence in function body: 'scrum'=$has_scrum, 'todos'=$has_todos, 'tasks'=$has_tasks"
        ERRORS=$((ERRORS + 1))
    else
        echo "PASS: Function '$fn' properly normalizes 'scrum' and 'todos' to 'tasks'."
    fi
done

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "ERROR: WidgetRegistry verification failed with $ERRORS error(s)."
    exit 1
else
    echo "PASS: All required functions in WidgetRegistry.qml normalize 'scrum' and 'todos' to 'tasks'."
    exit 0
fi
