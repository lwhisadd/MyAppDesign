#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "$SCRIPT_DIR/../common.sh"

require_cmds jq

TASK_ID="${1:-}"
if [[ -z "$TASK_ID" ]]; then
  json_ok --arg error "usage: review-task.sh <task_id>" '{ok:false,error:$error}'
  exit 10
fi

RESULT_DIR="$(task_dir_codex_results "$TASK_ID")"
MANIFEST_PATH="$RESULT_DIR/execution-manifest.json"
RESULT_PATH="$RESULT_DIR/result.json"
CHANGED_FILES_PATH="$RESULT_DIR/changed-files.txt"
PATCH_PATH="$RESULT_DIR/changes.patch"
ACCEPTANCE_PATH="$RESULT_DIR/acceptance.json"
REVIEW_JSON_PATH="$RESULT_DIR/codex-review.json"
REVIEW_MD_PATH="$RESULT_DIR/codex-review.md"

if [[ ! -f "$MANIFEST_PATH" || ! -f "$RESULT_PATH" ]]; then
  json_ok --arg error "manifest_or_result_missing" '{ok:false,error:$error}'
  exit 12
fi

WORKTREE_PATH="$(jq -r '.execution.worktree_path // empty' "$RESULT_PATH")"
if [[ -z "$WORKTREE_PATH" ]]; then
  WORKTREE_PATH="$CODEX_WORKTREES_ROOT/$TASK_ID"
fi

ACCEPTANCE_TMP="$(mktemp)"
ALL_COMMANDS_PASS=true
if [[ ! -d "$WORKTREE_PATH" ]]; then
  ALL_COMMANDS_PASS=false
fi

printf '[]' > "$ACCEPTANCE_TMP"
while IFS= read -r cmd; do
  [[ -n "$cmd" ]] || continue
  CMD_STATUS="pass"
  CMD_EXIT=0
  if [[ ! -d "$WORKTREE_PATH" ]]; then
    CMD_STATUS="not_run"
    CMD_EXIT=16
  else
    if ! bash -lc "cd \"${WORKTREE_PATH}\" && ${cmd}" >/dev/null 2>&1; then
      CMD_STATUS="fail"
      CMD_EXIT=$?
      ALL_COMMANDS_PASS=false
    fi
  fi
  jq \
    --arg command "$cmd" \
    --arg status "$CMD_STATUS" \
    --argjson exit_code "$CMD_EXIT" \
    '. + [{command:$command,status:$status,exit_code:$exit_code}]' \
    "$ACCEPTANCE_TMP" > "${ACCEPTANCE_TMP}.next"
  mv "${ACCEPTANCE_TMP}.next" "$ACCEPTANCE_TMP"
done < <(jq -r '.acceptance_commands[]' "$MANIFEST_PATH")

jq -n \
  --arg task_id "$TASK_ID" \
  --arg checked_at "$(iso_now)" \
  --arg worktree_path "$WORKTREE_PATH" \
  --slurpfile results "$ACCEPTANCE_TMP" \
  '{
    task_id: $task_id,
    checked_at: $checked_at,
    worktree_path: $worktree_path,
    commands: $results[0]
  }' > "$ACCEPTANCE_PATH"

ALLOWED_PATHS_JSON="$(jq -c '[.allowed_paths[], (.modules[]?.allowed_paths[]?)] | unique' "$MANIFEST_PATH")"
SCOPE_VALID=true
if [[ -f "$CHANGED_FILES_PATH" ]]; then
  while IFS= read -r changed; do
    [[ -n "$changed" ]] || continue
    if ! jq -e --arg changed "$changed" '
      any(.[]; ($changed == .) or ($changed | startswith(. + "/")))
    ' <<<"$ALLOWED_PATHS_JSON" >/dev/null; then
      SCOPE_VALID=false
      break
    fi
  done < "$CHANGED_FILES_PATH"
fi

RESULT_STATUS="$(jq -r '.status // "failed"' "$RESULT_PATH")"
REVIEW_STATUS="failed"
if [[ "$RESULT_STATUS" == "completed" && "$ALL_COMMANDS_PASS" == "true" && "$SCOPE_VALID" == "true" ]]; then
  REVIEW_STATUS="accepted"
fi

jq -n \
  --arg task_id "$TASK_ID" \
  --arg reviewer "codex" \
  --arg status "$REVIEW_STATUS" \
  --arg commit_sha "$(jq -r '.commit_sha // ""' "$RESULT_PATH")" \
  --arg patch_path "$PATCH_PATH" \
  --argjson scope_valid "$SCOPE_VALID" \
  --argjson tests_passed "$ALL_COMMANDS_PASS" \
  '{
    task_id: $task_id,
    reviewer: $reviewer,
    status: $status,
    commit_sha: (if $commit_sha == "" then null else $commit_sha end),
    scope_valid: $scope_valid,
    tests_passed: $tests_passed,
    patch_path: $patch_path,
    security_findings: [],
    required_changes: (if $status == "accepted" then [] else ["Review acceptance output and changed files before marking accepted."] end),
    merge_recommended: ($status == "accepted"),
    human_approval_required: false
  }' > "$REVIEW_JSON_PATH"

cat > "$REVIEW_MD_PATH" <<EOF
# Codex Review Summary

- Task ID: \`$TASK_ID\`
- Review status: \`$REVIEW_STATUS\`
- Worktree: \`$WORKTREE_PATH\`
- Scope valid: \`$SCOPE_VALID\`
- Acceptance commands passed: \`$ALL_COMMANDS_PASS\`
- Result file: \`$RESULT_PATH\`

## Notes

- This is the MVP shell review skeleton.
- If review status is \`failed\`, inspect \`acceptance.json\`, \`changes.patch\`, and \`changed-files.txt\`.
EOF

rm -f "$ACCEPTANCE_TMP"

json_ok \
  --arg task_id "$TASK_ID" \
  --arg review_status "$REVIEW_STATUS" \
  --arg acceptance_path "$ACCEPTANCE_PATH" \
  --arg review_json_path "$REVIEW_JSON_PATH" \
  --arg review_md_path "$REVIEW_MD_PATH" \
  '{ok:true,task_id:$task_id,review_status:$review_status,acceptance_path:$acceptance_path,review_json_path:$review_json_path,review_md_path:$review_md_path}'

