#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "$SCRIPT_DIR/../common.sh"

require_cmds jq sqlite3

TASK_ID="${1:-}"
if [[ -z "$TASK_ID" ]]; then
  json_ok --arg error "usage: dispatch-task.sh <task_id>" '{ok:false,error:$error}'
  exit 10
fi

TASK_DIR="$(task_dir_hermes "$TASK_ID")"
MANIFEST_PATH="$TASK_DIR/execution-manifest.json"
VALIDATION_PATH="$TASK_DIR/manifest-validation-result.json"
PREFLIGHT_PATH="$TASK_DIR/worker-preflight-result.json"
RESULT_PATH="$TASK_DIR/result.json"

if [[ ! -f "$MANIFEST_PATH" || ! -f "$VALIDATION_PATH" ]]; then
  json_ok --arg error "manifest_or_validation_missing" '{ok:false,error:$error}'
  exit 12
fi

if [[ "$(jq -r '.summary.dispatch_allowed // .dispatch_allowed // false' "$VALIDATION_PATH")" != "true" ]]; then
  json_ok --arg error "dispatch_not_allowed" '{ok:false,error:$error}'
  exit 17
fi

AGENT="${FORCE_AGENT:-$(jq -r '.modules[0].preferred_agent // "opencode"' "$MANIFEST_PATH")}"
if [[ "$AGENT" != "opencode" ]]; then
  json_ok --arg error "unsupported_agent_in_mvp" --arg agent "$AGENT" '{ok:false,error:$error,agent:$agent}'
  exit 14
fi

WRAPPER_BIN="${WORKER_OPENCODE_BIN:-/srv/agent/bin/run-opencode}"
if [[ ! -x "$WRAPPER_BIN" ]]; then
  json_ok --arg error "worker_wrapper_missing" --arg wrapper "$WRAPPER_BIN" '{ok:false,error:$error,wrapper:$wrapper}'
  exit 12
fi

"$SCRIPT_DIR/task-update-phase.sh" "$TASK_ID" "dispatched" "running" >/dev/null
"$WRAPPER_BIN" "$TASK_ID" "$MANIFEST_PATH" "$VALIDATION_PATH" "$TASK_DIR"

if [[ -f "$PREFLIGHT_PATH" && "$(jq -r '.preflight.available // false' "$PREFLIGHT_PATH")" != "true" ]]; then
  "$SCRIPT_DIR/task-update-phase.sh" "$TASK_ID" "blocked" "blocked" >/dev/null
  json_ok \
    --arg task_id "$TASK_ID" \
    --arg worker_id "$(jq -r '.worker_id // ""' "$PREFLIGHT_PATH")" \
    --arg preflight_path "$PREFLIGHT_PATH" \
    '{ok:true,task_id:$task_id,worker_id:$worker_id,preflight_path:$preflight_path,result_path:null}'
  exit 0
fi

if [[ ! -f "$RESULT_PATH" ]]; then
  json_ok --arg error "result_missing" '{ok:false,error:$error}'
  exit 12
fi

RESULT_STATUS="$(jq -r '.status // "failed"' "$RESULT_PATH")"
case "$RESULT_STATUS" in
  completed)
    "$SCRIPT_DIR/task-update-phase.sh" "$TASK_ID" "reviewing" "reviewing" >/dev/null
    ;;
  blocked|quota_exhausted|auth_invalid|timeout)
    "$SCRIPT_DIR/task-update-phase.sh" "$TASK_ID" "blocked" "blocked" >/dev/null
    ;;
  *)
    "$SCRIPT_DIR/task-update-phase.sh" "$TASK_ID" "failed" "failed" >/dev/null
    ;;
esac

json_ok \
  --arg task_id "$TASK_ID" \
  --arg worker_id "$(jq -r '.worker_id // ""' "$RESULT_PATH")" \
  --arg preflight_path "$PREFLIGHT_PATH" \
  --arg result_path "$RESULT_PATH" \
  '{ok:true,task_id:$task_id,worker_id:$worker_id,preflight_path:$preflight_path,result_path:$result_path}'

