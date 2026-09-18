#!/usr/bin/env bash

# Start spicetify -s watch in the background and capture its PID
spicetify -s watch &
SPICETIFY_PID=$!

# Trap signals (e.g., Ctrl+C) to ensure the background process dies if canceled early
trap 'kill "$SPICETIFY_PID" 2>/dev/null; exit 0' INT TERM EXIT

# Pipe the process output while monitoring for the completion signal
spicetify -s watch 2>&1 | while read -r line; do
    echo "$line"
    # Adjust "Success" or "Bundle compiled" if your specific extension output differs
    if [[ "$line" =~ "Success" || "$line" =~ "compiled" || "$line" =~ "built" ]]; then
        echo "Build completed. Terminating watcher..."
        kill "$SPICETIFY_PID" 2>/dev/null
        break
    fi
done

# Clear trap to avoid duplicate calls on exit
trap - INT TERM EXIT
exit 0