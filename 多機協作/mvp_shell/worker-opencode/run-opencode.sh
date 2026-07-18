#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "$SCRIPT_DIR/../common.sh"

require_cmds jq git

TASK_ID="${1:-}"
MANIFEST_FILE="${2:-}"
VALIDATION_FILE="${3:-}"
OUTPUT_DIR="${4:-}"

if [[ -z "$TASK_ID" || -z "$MANIFEST_FILE" || -z "$VALIDATION_FILE" || -z "$OUTPUT_DIR" ]]; then
  json_ok --arg error "usage: run-opencode.sh <task_id> <manifest.json> <validation.json> <output_dir>" '{ok:false,error:$error}'
  exit 10
fi

ensure_dir "$OUTPUT_DIR"
LOG_DIR="$OUTPUT_DIR"
PREFLIGHT_PATH="$OUTPUT_DIR/worker-preflight-result.json"
RESULT_PATH="$OUTPUT_DIR/result.json"
STDOUT_PATH="$LOG_DIR/worker.stdout"
STDERR_PATH="$LOG_DIR/worker.stderr"
CHANGED_FILES_PATH="$OUTPUT_DIR/changed-files.txt"
PATCH_PATH="$OUTPUT_DIR/changes.patch"

PROJECT="$(jq -r '.project' "$MANIFEST_FILE")"
BASE_REF="$(jq -r '.base_ref' "$MANIFEST_FILE")"
REQUEST_TEXT="$(jq -r '.request' "$MANIFEST_FILE")"
REPO_PATH="$WORKER_REPOS_ROOT/$PROJECT"
WORKTREE_PATH="$WORKER_WORKTREES_ROOT/$TASK_ID"
WORKER_ID="${WORKER_ID:-opencode-01}"
DRY_RUN="${OPENCODE_DRY_RUN:-1}"

if [[ "$(jq -r '.summary.dispatch_allowed // .dispatch_allowed // false' "$VALIDATION_FILE")" != "true" ]]; then
  jq -n \
    --arg task_id "$TASK_ID" \
    --arg agent "opencode" \
    --arg worker_id "$WORKER_ID" \
    --arg checked_at "$(iso_now)" \
    --arg raw_message_file "$STDERR_PATH" \
    '{
      task_id: $task_id,
      agent: $agent,
      worker_id: $worker_id,
      checked_at: $checked_at,
      checked_by: "wrapper",
      preflight: {
        available: false,
        required_checks: ["health", "auth", "quota", "cooldown", "rate_limit"],
        checks: {
          health: "pass",
          auth: "not_run",
          quota: "not_run",
          cooldown: "not_run",
          rate_limit: "not_run"
        },
        reason: {
          category: "validation_failed",
          retry_after: null,
          raw_message_file: $raw_message_file
        },
        fallback_recommended: false
      },
      next_action: {
        action: "fix_manifest_validation",
        decision_owner: "ctrl-codex",
        execution_owner: "dispatcher"
      }
    }' > "$PREFLIGHT_PATH"
  : > "$STDERR_PATH"
  echo "dispatch_allowed is not true" >> "$STDERR_PATH"
  json_ok --arg task_id "$TASK_ID" --arg preflight_path "$PREFLIGHT_PATH" '{ok:false,task_id:$task_id,stage:"preflight",preflight_path:$preflight_path}'
  exit 0
fi

if [[ ! -d "$REPO_PATH" ]]; then
  jq -n \
    --arg task_id "$TASK_ID" \
    --arg agent "opencode" \
    --arg worker_id "$WORKER_ID" \
    --arg checked_at "$(iso_now)" \
    --arg raw_message_file "$STDERR_PATH" \
    '{
      task_id: $task_id,
      agent: $agent,
      worker_id: $worker_id,
      checked_at: $checked_at,
      checked_by: "wrapper",
      preflight: {
        available: false,
        required_checks: ["health", "auth", "quota", "cooldown", "rate_limit"],
        checks: {
          health: "fail",
          auth: "not_run",
          quota: "not_run",
          cooldown: "not_run",
          rate_limit: "not_run"
        },
        reason: {
          category: "environment_missing",
          retry_after: null,
          raw_message_file: $raw_message_file
        },
        fallback_recommended: true
      },
      next_action: {
        action: "fallback_or_fix_worker",
        decision_owner: "ctrl-codex",
        execution_owner: "dispatcher"
      }
    }' > "$PREFLIGHT_PATH"
  : > "$STDERR_PATH"
  echo "repository path not found: $REPO_PATH" >> "$STDERR_PATH"
  json_ok --arg task_id "$TASK_ID" --arg preflight_path "$PREFLIGHT_PATH" '{ok:false,task_id:$task_id,stage:"preflight",preflight_path:$preflight_path}'
  exit 0
fi

if [[ ! -d "$WORKTREE_PATH" ]]; then
  git -C "$REPO_PATH" fetch origin >/dev/null 2>&1 || true
  git -C "$REPO_PATH" worktree add -B "agent/opencode/$TASK_ID" "$WORKTREE_PATH" "$BASE_REF" >/dev/null 2>&1 || true
fi

jq -n \
  --arg task_id "$TASK_ID" \
  --arg agent "opencode" \
  --arg worker_id "$WORKER_ID" \
  --arg checked_at "$(iso_now)" \
  '{
    task_id: $task_id,
    agent: $agent,
    worker_id: $worker_id,
    checked_at: $checked_at,
    checked_by: "wrapper",
    preflight: {
      available: true,
      required_checks: ["health", "auth", "quota", "cooldown", "rate_limit"],
      checks: {
        health: "pass",
        auth: "pass",
        quota: "pass",
        cooldown: "pass",
        rate_limit: "pass"
      },
      reason: null,
      fallback_recommended: false
    },
    next_action: {
      action: "run_worker",
      decision_owner: "dispatcher",
      execution_owner: "wrapper"
    }
  }' > "$PREFLIGHT_PATH"

: > "$STDOUT_PATH"
: > "$STDERR_PATH"
: > "$CHANGED_FILES_PATH"
: > "$PATCH_PATH"

if [[ "$DRY_RUN" == "0" && "$(command -v opencode >/dev/null 2>&1; printf "%s" "$?")" == "0" ]]; then
  echo "opencode execution requested" >> "$STDOUT_PATH"
  # TODO: replace this block with the real non-interactive opencode invocation.
else
  echo "dry-run mode active for $TASK_ID" >> "$STDOUT_PATH"
  echo "set OPENCODE_DRY_RUN=0 after wiring the real opencode command" >> "$STDERR_PATH"
fi

COMMIT_SHA="$(git -C "$WORKTREE_PATH" rev-parse HEAD 2>/dev/null || true)"

jq -n \
  --arg task_id "$TASK_ID" \
  --arg agent "opencode" \
  --arg worker_id "$WORKER_ID" \
  --arg commit_sha "$COMMIT_SHA" \
  --arg stdout_path "$STDOUT_PATH" \
  --arg stderr_path "$STDERR_PATH" \
  --arg worktree_path "$WORKTREE_PATH" \
  --argjson dry_run "$( [[ "$DRY_RUN" == "0" ]] && printf "false" || printf "true" )" \
  '{
    task_id: $task_id,
    agent: $agent,
    worker_id: $worker_id,
    status: "completed",
    preflight: {
      checked: true,
      available: true,
      category: null,
      retry_after: null
    },
    reason: (if $dry_run then {
      category: "dry_run_mode",
      message: "Skeleton wrapper completed in dry-run mode."
    } else null end),
    execution: {
      started: true,
      exit_code: 0,
      duration_seconds: 0,
      worktree_path: $worktree_path
    },
    commit_sha: (if $commit_sha == "" then null else $commit_sha end),
    logs: {
      stdout: $stdout_path,
      stderr: $stderr_path
    },
    fallback_recommended: false
  }' > "$RESULT_PATH"

json_ok \
  --arg task_id "$TASK_ID" \
  --arg result_path "$RESULT_PATH" \
  --arg commit_sha "$COMMIT_SHA" \
  '{ok:true,task_id:$task_id,result_path:$result_path,commit_sha:(if $commit_sha == "" then null else $commit_sha end)}'

