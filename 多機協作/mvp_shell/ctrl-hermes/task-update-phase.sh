#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "$SCRIPT_DIR/../common.sh"

require_cmds jq sqlite3

TASK_ID="${1:-}"
PHASE="${2:-}"
STATUS="${3:-}"
VALID_PHASES=(enveloped planned dispatched running reviewing accepted failed blocked)
VALID_STATUSES=(queued ready running reviewing succeeded failed blocked)

if [[ -z "$TASK_ID" || -z "$PHASE" || -z "$STATUS" ]]; then
  json_ok --arg error "usage: task-update-phase.sh <task_id> <phase> <status>" '{ok:false,error:$error}'
  exit 10
fi

if ! task_exists_in_db "$TASK_ID"; then
  json_ok --arg error "task_not_found" '{ok:false,error:$error}'
  exit 11
fi

if ! contains_word "$PHASE" "${VALID_PHASES[@]}"; then
  json_ok --arg error "invalid_phase" --arg phase "$PHASE" '{ok:false,error:$error,phase:$phase}'
  exit 14
fi

if ! contains_word "$STATUS" "${VALID_STATUSES[@]}"; then
  json_ok --arg error "invalid_status" --arg status "$STATUS" '{ok:false,error:$error,status:$status}'
  exit 14
fi

NOW="$(iso_now)"
STARTED_SQL=""
FINISHED_SQL=""
if [[ "$PHASE" == "running" ]]; then
  STARTED_SQL=", started_at = COALESCE(started_at, '$(sql_escape "$NOW")')"
fi
if [[ "$PHASE" == "accepted" || "$PHASE" == "failed" || "$PHASE" == "blocked" ]]; then
  FINISHED_SQL=", finished_at = '$(sql_escape "$NOW")'"
fi

CHANGES="$(
  sqlite3 "$HERMES_DB" <<SQL
UPDATE task_executions
SET current_phase = '$(sql_escape "$PHASE")',
    status = '$(sql_escape "$STATUS")',
    updated_at = '$(sql_escape "$NOW")'
    $STARTED_SQL
    $FINISHED_SQL
WHERE task_id = '$(sql_escape "$TASK_ID")';
SELECT changes();
SQL
)"
CHANGES="$(printf "%s" "$CHANGES" | tail -n 1 | tr -d '[:space:]')"

if [[ "$CHANGES" != "1" ]]; then
  json_ok --arg error "update_failed" --arg task_id "$TASK_ID" '{ok:false,error:$error,task_id:$task_id}'
  exit 15
fi

json_ok \
  --arg task_id "$TASK_ID" \
  --arg phase "$PHASE" \
  --arg status "$STATUS" \
  '{ok:true,task_id:$task_id,phase:$phase,status:$status}'

