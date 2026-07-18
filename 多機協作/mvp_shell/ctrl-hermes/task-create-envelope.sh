#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "$SCRIPT_DIR/../common.sh"

require_cmds jq sqlite3 date mkdir

REQUEST_FILE="${1:-}"
if [[ -z "$REQUEST_FILE" || ! -f "$REQUEST_FILE" ]]; then
  json_ok --arg error "usage: task-create-envelope.sh <request.json>" '{ok:false,error:$error}'
  exit 10
fi

jq -e '
  .project and .request and .source and .priority and
  (.requires_human_approval != null)
' "$REQUEST_FILE" >/dev/null

PROJECT="$(jq -r '.project' "$REQUEST_FILE")"
REQUEST_TEXT="$(jq -r '.request' "$REQUEST_FILE")"
SOURCE_VALUE="$(jq -r '.source' "$REQUEST_FILE")"
PRIORITY="$(jq -r '.priority' "$REQUEST_FILE")"
REQUIRES_APPROVAL="$(jq -r '.requires_human_approval' "$REQUEST_FILE")"
CREATED_BY="$(jq -r '.created_by // ""' "$REQUEST_FILE")"
APPROVAL_NOTE="$(jq -r '.approval_note // ""' "$REQUEST_FILE")"
NOW="$(iso_now)"
TODAY="$(date -u +"%Y%m%d")"

ensure_dir "$HERMES_TASKS_ROOT"

SEQ="$(sqlite3 "$HERMES_DB" "SELECT printf('%03d', COALESCE(MAX(CAST(substr(task_id, 15) AS INTEGER)), 0) + 1) FROM task_envelopes WHERE task_id LIKE 'TASK-${TODAY}-%';")"
TASK_ID="TASK-${TODAY}-${SEQ}"
TASK_DIR="$(task_dir_hermes "$TASK_ID")"
ENVELOPE_PATH="$TASK_DIR/task-envelope.json"

ensure_dir "$TASK_DIR"

jq -n \
  --arg schema_version "1.0.0" \
  --arg task_id "$TASK_ID" \
  --arg project "$PROJECT" \
  --arg request "$REQUEST_TEXT" \
  --arg source "$SOURCE_VALUE" \
  --arg priority "$PRIORITY" \
  --arg created_at "$NOW" \
  --arg created_by "$CREATED_BY" \
  --arg approval_note "$APPROVAL_NOTE" \
  --argjson requires_human_approval "$REQUIRES_APPROVAL" \
  '{
    schema_version: $schema_version,
    task_id: $task_id,
    project: $project,
    request: $request,
    source: $source,
    priority: $priority,
    requires_human_approval: $requires_human_approval,
    created_at: $created_at
  }
  + (if $created_by != "" then {created_by: $created_by} else {} end)
  + (if $approval_note != "" then {approval_note: $approval_note} else {} end)
  ' > "$ENVELOPE_PATH"

sqlite3 "$HERMES_DB" <<SQL
BEGIN;
INSERT INTO task_envelopes (
  task_id, project, request, source, priority,
  requires_human_approval, approval_status, approval_note,
  created_at, created_by, updated_at
) VALUES (
  '$(sql_escape "$TASK_ID")',
  '$(sql_escape "$PROJECT")',
  '$(sql_escape "$REQUEST_TEXT")',
  '$(sql_escape "$SOURCE_VALUE")',
  '$(sql_escape "$PRIORITY")',
  $( [[ "$REQUIRES_APPROVAL" == "true" ]] && printf "1" || printf "0" ),
  $( [[ "$REQUIRES_APPROVAL" == "true" ]] && printf "'pending'" || printf "'not_required'" ),
  $( [[ -n "$APPROVAL_NOTE" ]] && printf "'%s'" "$(sql_escape "$APPROVAL_NOTE")" || printf "NULL" ),
  '$(sql_escape "$NOW")',
  $( [[ -n "$CREATED_BY" ]] && printf "'%s'" "$(sql_escape "$CREATED_BY")" || printf "NULL" ),
  '$(sql_escape "$NOW")'
);
INSERT INTO task_executions (
  task_id, project, current_phase, status, updated_at
) VALUES (
  '$(sql_escape "$TASK_ID")',
  '$(sql_escape "$PROJECT")',
  'enveloped',
  'queued',
  '$(sql_escape "$NOW")'
);
COMMIT;
SQL

json_ok \
  --arg task_id "$TASK_ID" \
  --arg task_dir "$TASK_DIR" \
  --arg envelope_path "$ENVELOPE_PATH" \
  '{ok:true,task_id:$task_id,task_dir:$task_dir,envelope_path:$envelope_path}'

