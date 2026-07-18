#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "$SCRIPT_DIR/../common.sh"

require_cmds jq sqlite3 cp

TASK_ID="${1:-}"
MANIFEST_FILE="${2:-}"
if [[ -z "$TASK_ID" || -z "$MANIFEST_FILE" || ! -f "$MANIFEST_FILE" ]]; then
  json_ok --arg error "usage: task-store-manifest.sh <task_id> <manifest.json>" '{ok:false,error:$error}'
  exit 10
fi

if ! task_exists_in_db "$TASK_ID"; then
  json_ok --arg error "task_not_found" '{ok:false,error:$error}'
  exit 11
fi

jq -e '.task_id and .project and .modules' "$MANIFEST_FILE" >/dev/null

TASK_DIR="$(task_dir_hermes "$TASK_ID")"
ensure_dir "$TASK_DIR"
TARGET_PATH="$TASK_DIR/execution-manifest.json"
cp "$MANIFEST_FILE" "$TARGET_PATH"
NOW="$(iso_now)"

sqlite3 "$HERMES_DB" <<SQL
UPDATE task_executions
SET execution_manifest_path = '$(sql_escape "$TARGET_PATH")',
    updated_at = '$(sql_escape "$NOW")'
WHERE task_id = '$(sql_escape "$TASK_ID")';
SQL

json_ok \
  --arg task_id "$TASK_ID" \
  --arg stored_path "$TARGET_PATH" \
  '{ok:true,task_id:$task_id,stored_path:$stored_path}'

