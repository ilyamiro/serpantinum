#!/usr/bin/env bash
set -e

[[ ${1:-} == "--verbose" ]] && shift

TASKS_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/serpantinum/quickactions"
TASKS_FILE="$TASKS_DIR/tasks.json"

USE_COLOR=false
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    USE_COLOR=true
fi

if [ "$USE_COLOR" = true ]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[2m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_MAGENTA=$'\033[35m'
    C_CYAN=$'\033[36m'
    C_GRAY=$'\033[90m'
else
    C_RESET=''
    C_BOLD=''
    C_DIM=''
    C_RED=''
    C_GREEN=''
    C_YELLOW=''
    C_BLUE=''
    C_MAGENTA=''
    C_CYAN=''
    C_GRAY=''
fi

show_help() {
    cat <<EOF
Usage: serpantinum tasks <command> [options]

Commands:
  list [--json]                                 List tasks
  add <title> [--points N] [--priority P] [--status S]
                                                Add a new task
  done [task_id]                                Mark task as done (default: first in_progress/pending)
  next [task_id]                                Advance task status (default: first pending to in_progress)
  delete <task_id>                              Delete a task by ID
  clear-done                                    Remove all completed tasks
  status                                        Show methodology and status summary

Options:
  --points N       Story points (integer, default: 0)
  --priority P     Priority: low, medium, high, urgent (default: medium)
  --status S       Status: todo, sprint, in_progress, done (default: todo)
  --json           Output in raw JSON format (supported on list and status)
  -h, --help       Show this help message
EOF
}

init_file_if_needed() {
    mkdir -p "$TASKS_DIR"
    if [ ! -f "$TASKS_FILE" ] || [ ! -s "$TASKS_FILE" ] || ! jq -e . "$TASKS_FILE" >/dev/null 2>&1; then
        local default_json='{
  "methodology": "simple",
  "cycleName": "",
  "cycleGoal": "",
  "sprint": {
    "name": "",
    "goal": ""
  },
  "wipLimit": 2,
  "tasks": []
}'
        local tmp="${TASKS_FILE}.tmp.$RANDOM.$$"
        printf '%s\n' "$default_json" > "$tmp" && mv -f "$tmp" "$TASKS_FILE"
    fi
}

atomic_save() {
    local json_data="$1"
    mkdir -p "$TASKS_DIR"
    local tmp="${TASKS_FILE}.tmp.$RANDOM.$$"
    if printf '%s\n' "$json_data" | jq . > "$tmp" && mv -f "$tmp" "$TASKS_FILE"; then
        return 0
    else
        rm -f "$tmp" 2>/dev/null
        echo "Error: failed to write tasks atomically." >&2
        return 1
    fi
}

cmd_list() {
    local json_output=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --json)
                json_output=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done

    init_file_if_needed

    if [ "$json_output" = true ]; then
        jq '.tasks // []' "$TASKS_FILE"
        return 0
    fi

    local task_count
    task_count=$(jq '(.tasks // []) | length' "$TASKS_FILE")

    if [ "$task_count" -eq 0 ]; then
        echo "No tasks found."
        return 0
    fi

    printf "${C_BOLD}%-24s  %-12s  %-10s  %3s  %s${C_RESET}\n" "ID" "STATUS" "PRIORITY" "PTS" "TITLE"

    while IFS= read -r -d '' id &&
          IFS= read -r -d '' status &&
          IFS= read -r -d '' priority &&
          IFS= read -r -d '' points &&
          IFS= read -r -d '' title; do

        local st_col="$C_RESET"
        case "$status" in
            done)        st_col="$C_GREEN" ;;
            in_progress) st_col="$C_YELLOW" ;;
            sprint)      st_col="$C_CYAN" ;;
            backlog)     st_col="$C_MAGENTA" ;;
            *)           st_col="$C_BLUE" ;;
        esac

        local pr_col="$C_RESET"
        case "$priority" in
            urgent) pr_col="$C_BOLD$C_RED" ;;
            high)   pr_col="$C_RED" ;;
            medium) pr_col="$C_YELLOW" ;;
            *)      pr_col="$C_GRAY" ;;
        esac

        if [ "$USE_COLOR" = true ]; then
            printf "%-24s  ${st_col}%-12s${C_RESET}  ${pr_col}%-10s${C_RESET}  %3s  %s\n" \
                "$id" "$status" "$priority" "$points" "$title"
        else
            printf "%-24s  %-12s  %-10s  %3s  %s\n" \
                "$id" "$status" "$priority" "$points" "$title"
        fi
    done < <(jq -j '(.tasks // [])[] | (.id // ""), "\u0000", (.status // "todo"), "\u0000", (.priority // "medium"), "\u0000", ((.points // 0) | tostring), "\u0000", (.title // ""), "\u0000"' "$TASKS_FILE")
}

cmd_add() {
    local title=""
    local points=0
    local priority="medium"
    local status="todo"

    while [ $# -gt 0 ]; do
        case "$1" in
            --points)
                points="${2:-0}"
                shift 2
                ;;
            --points=*)
                points="${1#*=}"
                shift
                ;;
            --priority)
                priority="${2:-medium}"
                shift 2
                ;;
            --priority=*)
                priority="${1#*=}"
                shift
                ;;
            --status)
                status="${2:-todo}"
                shift 2
                ;;
            --status=*)
                status="${1#*=}"
                shift
                ;;
            *)
                if [ -z "$title" ]; then
                    title="$1"
                else
                    title="$title $1"
                fi
                shift
                ;;
        esac
    done

    if [ -z "$title" ]; then
        echo "Error: task title is required." >&2
        echo "Usage: serpantinum tasks add <title> [--points N] [--priority low|medium|high|urgent] [--status todo|sprint|in_progress|done]" >&2
        return 1
    fi

    if ! [[ "$points" =~ ^[0-9]+$ ]]; then
        echo "Error: points must be a non-negative integer." >&2
        return 1
    fi

    case "$priority" in
        low|medium|high|urgent) ;;
        *)
            echo "Error: invalid priority '$priority' (expected low, medium, high, urgent)." >&2
            return 1
            ;;
    esac

    case "$status" in
        todo|sprint|in_progress|done|backlog) ;;
        *)
            echo "Error: invalid status '$status' (expected todo, sprint, in_progress, done)." >&2
            return 1
            ;;
    esac

    init_file_if_needed

    local timestamp rand task_id
    timestamp=$(date +%s%3N 2>/dev/null || date +%s)
    rand=$(( RANDOM % 1000 ))
    task_id="task_${timestamp}_${rand}"

    local new_task
    if [ "$status" = "done" ]; then
        new_task=$(jq -n \
            --arg id "$task_id" \
            --arg title "$title" \
            --argjson points "$points" \
            --arg priority "$priority" \
            --arg status "$status" \
            --argjson createdAt "$timestamp" \
            --argjson completedAt "$timestamp" \
            '{id: $id, title: $title, points: $points, priority: $priority, status: $status, createdAt: $createdAt, completedAt: $completedAt}')
    else
        new_task=$(jq -n \
            --arg id "$task_id" \
            --arg title "$title" \
            --argjson points "$points" \
            --arg priority "$priority" \
            --arg status "$status" \
            --argjson createdAt "$timestamp" \
            '{id: $id, title: $title, points: $points, priority: $priority, status: $status, createdAt: $createdAt}')
    fi

    local updated
    updated=$(jq --argjson task "$new_task" '.tasks = [$task] + (.tasks // [])' "$TASKS_FILE")
    atomic_save "$updated"

    echo "Task added: $task_id (\"$title\")"
}

cmd_done() {
    init_file_if_needed

    local task_id="${1:-}"

    if [ -z "$task_id" ]; then
        task_id=$(jq -r '
            (.tasks // []) as $t |
            ($t | map(select(.status == "in_progress")) | first | .id) //
            ($t | map(select(.status == "todo" or .status == "sprint" or .status == "backlog")) | first | .id) //
            empty
        ' "$TASKS_FILE")

        if [ -z "$task_id" ]; then
            echo "No pending task found to mark as done." >&2
            return 1
        fi
    else
        if ! jq -e --arg id "$task_id" '(.tasks // []) | any(.id == $id)' "$TASKS_FILE" >/dev/null 2>&1; then
            echo "Error: task '$task_id' not found." >&2
            return 1
        fi
    fi

    local timestamp
    timestamp=$(date +%s%3N 2>/dev/null || date +%s)

    local updated title
    title=$(jq -r --arg id "$task_id" '(.tasks // [])[] | select(.id == $id) | .title' "$TASKS_FILE")
    updated=$(jq --arg id "$task_id" --argjson now "$timestamp" '
        .tasks |= map(if .id == $id then .status = "done" | .completedAt = $now else . end)
    ' "$TASKS_FILE")

    atomic_save "$updated"
    echo "Marked task as done: $task_id (\"$title\")"
}

cmd_next() {
    init_file_if_needed

    local task_id="${1:-}"

    if [ -z "$task_id" ]; then
        task_id=$(jq -r '
            (.tasks // []) as $t |
            ($t | map(select(.status == "todo" or .status == "sprint" or .status == "backlog")) | first | .id) //
            empty
        ' "$TASKS_FILE")

        if [ -z "$task_id" ]; then
            echo "No pending task found to advance." >&2
            return 1
        fi
    else
        if ! jq -e --arg id "$task_id" '(.tasks // []) | any(.id == $id)' "$TASKS_FILE" >/dev/null 2>&1; then
            echo "Error: task '$task_id' not found." >&2
            return 1
        fi
    fi

    local curr_status title
    curr_status=$(jq -r --arg id "$task_id" '(.tasks // [])[] | select(.id == $id) | .status' "$TASKS_FILE")
    title=$(jq -r --arg id "$task_id" '(.tasks // [])[] | select(.id == $id) | .title' "$TASKS_FILE")

    local next_status
    case "$curr_status" in
        todo|backlog|sprint)
            next_status="in_progress"
            ;;
        in_progress)
            next_status="done"
            ;;
        done)
            echo "Task '$task_id' is already done."
            return 0
            ;;
        *)
            next_status="in_progress"
            ;;
    esac

    local timestamp
    timestamp=$(date +%s%3N 2>/dev/null || date +%s)

    local updated
    if [ "$next_status" = "done" ]; then
        updated=$(jq --arg id "$task_id" --arg next "$next_status" --argjson now "$timestamp" '
            .tasks |= map(if .id == $id then .status = $next | .completedAt = $now else . end)
        ' "$TASKS_FILE")
    else
        updated=$(jq --arg id "$task_id" --arg next "$next_status" '
            .tasks |= map(if .id == $id then .status = $next | del(.completedAt) else . end)
        ' "$TASKS_FILE")
    fi

    atomic_save "$updated"
    echo "Advanced task: $task_id (\"$title\") -> $next_status"
}

cmd_delete() {
    init_file_if_needed

    local task_id="${1:-}"
    if [ -z "$task_id" ]; then
        echo "Error: task_id is required." >&2
        echo "Usage: serpantinum tasks delete <task_id>" >&2
        return 1
    fi

    if ! jq -e --arg id "$task_id" '(.tasks // []) | any(.id == $id)' "$TASKS_FILE" >/dev/null 2>&1; then
        echo "Error: task '$task_id' not found." >&2
        return 1
    fi

    local title
    title=$(jq -r --arg id "$task_id" '(.tasks // [])[] | select(.id == $id) | .title' "$TASKS_FILE")

    local updated
    updated=$(jq --arg id "$task_id" '.tasks |= map(select(.id != $id))' "$TASKS_FILE")

    atomic_save "$updated"
    echo "Deleted task: $task_id (\"$title\")"
}

cmd_clear_done() {
    init_file_if_needed

    local done_count
    done_count=$(jq '[ (.tasks // [])[] | select(.status == "done") ] | length' "$TASKS_FILE")

    if [ "$done_count" -eq 0 ]; then
        echo "No completed tasks to clear."
        return 0
    fi

    local updated
    updated=$(jq '.tasks |= map(select(.status != "done"))' "$TASKS_FILE")

    atomic_save "$updated"
    echo "Cleared $done_count completed task(s)."
}

cmd_status() {
    local json_output=false
    if [ "${1:-}" == "--json" ]; then
        json_output=true
    fi

    init_file_if_needed

    if [ "$json_output" = true ]; then
        jq '{
            methodology: (.methodology // "simple"),
            cycleName: (.cycleName // .sprint.name // ""),
            cycleGoal: (.cycleGoal // .sprint.goal // ""),
            wipLimit: (.wipLimit // 2),
            totalTasks: ((.tasks // []) | length),
            counts: {
                todo: ([ (.tasks // [])[] | select(.status == "todo") ] | length),
                in_progress: ([ (.tasks // [])[] | select(.status == "in_progress") ] | length),
                done: ([ (.tasks // [])[] | select(.status == "done") ] | length),
                sprint: ([ (.tasks // [])[] | select(.status == "sprint") ] | length),
                backlog: ([ (.tasks // [])[] | select(.status == "backlog") ] | length)
            }
        }' "$TASKS_FILE"
        return 0
    fi

    local info=()
    mapfile -t info < <(
        jq -r '
            .tasks // [] as $t |
            (
                (.methodology // "simple"),
                (.cycleName // .sprint.name // ""),
                (.cycleGoal // .sprint.goal // ""),
                ((.wipLimit // 2) | tostring),
                ($t | length | tostring),
                ([$t[] | select(.status == "todo")] | length | tostring),
                ([$t[] | select(.status == "in_progress")] | length | tostring),
                ([$t[] | select(.status == "done")] | length | tostring),
                ([$t[] | select(.status == "sprint")] | length | tostring),
                ([$t[] | select(.status == "backlog")] | length | tostring)
            )
        ' "$TASKS_FILE"
    )

    local methodology="${info[0]:-simple}"
    local cycle_name="${info[1]:-}"
    local cycle_goal="${info[2]:-}"
    local wip_limit="${info[3]:-2}"
    local total_tasks="${info[4]:-0}"
    local count_todo="${info[5]:-0}"
    local count_inprogress="${info[6]:-0}"
    local count_done="${info[7]:-0}"
    local count_sprint="${info[8]:-0}"
    local count_backlog="${info[9]:-0}"

    printf "${C_BOLD}Methodology:${C_RESET} %s (WIP limit: %s)\n" "$methodology" "$wip_limit"
    if [ -n "$cycle_name" ] || [ -n "$cycle_goal" ]; then
        local cycle_label="Cycle/Sprint"
        [ "$methodology" = "scrum" ] && cycle_label="Sprint"
        if [ -n "$cycle_name" ] && [ -n "$cycle_goal" ]; then
            printf "${C_BOLD}%s:${C_RESET} %s (Goal: %s)\n" "$cycle_label" "$cycle_name" "$cycle_goal"
        elif [ -n "$cycle_name" ]; then
            printf "${C_BOLD}%s:${C_RESET} %s\n" "$cycle_label" "$cycle_name"
        else
            printf "${C_BOLD}%s:${C_RESET} Goal: %s\n" "$cycle_label" "$cycle_goal"
        fi
    fi
    printf "${C_BOLD}Total Tasks:${C_RESET} %s\n\n" "$total_tasks"

    printf "${C_BOLD}Status Breakdown:${C_RESET}\n"
    if [ "$count_backlog" -gt 0 ] || [ "$methodology" = "scrum" ]; then
        printf "  ${C_MAGENTA}%-12s${C_RESET} %s\n" "backlog:" "$count_backlog"
    fi
    if [ "$count_sprint" -gt 0 ] || [ "$methodology" = "scrum" ]; then
        printf "  ${C_CYAN}%-12s${C_RESET} %s\n" "sprint:" "$count_sprint"
    fi
    printf "  ${C_BLUE}%-12s${C_RESET} %s\n" "todo:" "$count_todo"
    printf "  ${C_YELLOW}%-12s${C_RESET} %s\n" "in_progress:" "$count_inprogress"
    printf "  ${C_GREEN}%-12s${C_RESET} %s\n" "done:" "$count_done"
}

action="${1:-list}"
[ $# -gt 0 ] && shift

case "$action" in
    list)
        cmd_list "$@"
        ;;
    add)
        cmd_add "$@"
        ;;
    done)
        cmd_done "$@"
        ;;
    next)
        cmd_next "$@"
        ;;
    delete|del|rm)
        cmd_delete "$@"
        ;;
    clear-done)
        cmd_clear_done "$@"
        ;;
    status)
        cmd_status "$@"
        ;;
    --json)
        cmd_list --json
        ;;
    -h|--help|help)
        show_help
        ;;
    *)
        echo "Error: unknown subcommand '$action'." >&2
        show_help >&2
        exit 1
        ;;
esac
