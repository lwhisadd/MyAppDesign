#!/usr/bin/env bash
set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/srv/hermes-control}"
HERMES_TASKS_ROOT="${HERMES_TASKS_ROOT:-$HERMES_ROOT/tasks}"
HERMES_DB="${HERMES_DB:-$HERMES_ROOT/state/coordination.db}"

CODEX_ROOT="${CODEX_ROOT:-/srv/codex-supervisor}"
CODEX_TASKS_ROOT="${CODEX_TASKS_ROOT:-$CODEX_ROOT/tasks}"
CODEX_RESULTS_ROOT="${CODEX_RESULTS_ROOT:-$CODEX_ROOT/results}"
CODEX_WORKTREES_ROOT="${CODEX_WORKTREES_ROOT:-$CODEX_ROOT/worktrees}"

WORKER_ROOT="${WORKER_ROOT:-/srv/agent}"
WORKER_REPOS_ROOT="${WORKER_REPOS_ROOT:-$WORKER_ROOT/repos}"
WORKER_WORKTREES_ROOT="${WORKER_WORKTREES_ROOT:-$WORKER_ROOT/worktrees}"

json_ok() {
  jq -n "$@"
}

require_cmds() {
  local missing=()
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done
  if [[ "${#missing[@]}" -gt 0 ]]; then
    printf 'missing required commands: %s\n' "${missing[*]}" >&2
    exit 12
  fi
}

ensure_dir() {
  mkdir -p "$1"
}

iso_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

sql_escape() {
  local value="${1:-}"
  value="${value//\'/\'\'}"
  printf "%s" "$value"
}

contains_word() {
  local needle="${1:-}"
  shift
  local item
  for item in "$@"; do
    if [[ "$item" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

task_dir_hermes() {
  printf "%s/%s" "$HERMES_TASKS_ROOT" "$1"
}

task_dir_codex_tasks() {
  printf "%s/%s" "$CODEX_TASKS_ROOT" "$1"
}

task_dir_codex_results() {
  printf "%s/%s" "$CODEX_RESULTS_ROOT" "$1"
}

task_exists_in_db() {
  local task_id="${1:-}"
  local count
  count="$(sqlite3 "$HERMES_DB" "SELECT COUNT(1) FROM task_executions WHERE task_id = '$(sql_escape "$task_id")';")"
  [[ "$count" == "1" ]]
}

