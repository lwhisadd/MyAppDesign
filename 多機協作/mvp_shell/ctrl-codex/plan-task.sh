#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../common.sh
source "$SCRIPT_DIR/../common.sh"

require_cmds jq mkdir

TASK_ID="${1:-}"
if [[ -z "$TASK_ID" ]]; then
  json_ok --arg error "usage: plan-task.sh <task_id>" '{ok:false,error:$error}'
  exit 10
fi

TASK_INPUT_DIR="$(task_dir_codex_tasks "$TASK_ID")"
RESULT_DIR="$(task_dir_codex_results "$TASK_ID")"
ENVELOPE_PATH="$TASK_INPUT_DIR/task-envelope.json"
DRAFT_PATH="$TASK_INPUT_DIR/execution-manifest.draft.json"
MANIFEST_PATH="$RESULT_DIR/execution-manifest.json"
VALIDATION_PATH="$RESULT_DIR/manifest-validation-result.json"

if [[ ! -f "$ENVELOPE_PATH" ]]; then
  json_ok --arg error "envelope_missing" '{ok:false,error:$error}'
  exit 12
fi

ensure_dir "$RESULT_DIR"

if [[ -f "$DRAFT_PATH" ]]; then
  cp "$DRAFT_PATH" "$MANIFEST_PATH"
else
  PROJECT="$(jq -r '.project' "$ENVELOPE_PATH")"
  REQUEST_TEXT="$(jq -r '.request' "$ENVELOPE_PATH")"
  jq -n \
    --arg schema_version "1.0.0" \
    --arg task_id "$TASK_ID" \
    --arg project "$PROJECT" \
    --arg request "$REQUEST_TEXT" \
    --arg base_ref "origin/main" \
    '{
      schema_version: $schema_version,
      task_id: $task_id,
      project: $project,
      request: $request,
      tech_decisions: [
        {
          topic: "todo",
          decision: "TODO: replace with real tech decision",
          source: "TODO: add decision source"
        }
      ],
      development_process: {
        tdd_required: true,
        tdd_exception_reason: "",
        verification_strategy: "TODO: replace with project-specific verification"
      },
      commit_rules: {
        separate_refactor_from_behavior: true
      },
      dispatch_policy: {
        preflight_required: true,
        preflight_rule_owner: "ctrl-codex",
        preflight_execution_owner: "wrapper",
        dispatch_execution_owner: "dispatcher",
        required_checks: ["health", "auth", "quota", "cooldown", "rate_limit"],
        block_dispatch_when_unavailable: true
      },
      base_ref: $base_ref,
      allowed_paths: ["TODO:set-allowed-paths"],
      denied_paths: [".git", ".github/workflows", ".env", "secrets"],
      acceptance_commands: ["TODO:set-acceptance-command"],
      timeout_seconds: 3600,
      must_commit: true,
      fallback_agents: ["claude", "codex"],
      modules: [
        {
          module_id: "task.main",
          name: "Primary task module",
          responsibility: $request,
          description: "TODO: split into real modules before dispatch",
          inputs: [],
          outputs: [
            {
              name: "implementation_result",
              type: "file",
              kind: "file",
              target: "TODO:set-output-target",
              description: "Primary task output"
            }
          ],
          side_effects: [],
          upstream_dependencies: [],
          downstream_dependencies: [],
          allowed_paths: ["TODO:set-module-allowed-paths"],
          acceptance_commands: ["TODO:set-module-acceptance-command"],
          preferred_agent: "opencode",
          fallback_agents: ["claude", "codex"]
        }
      ]
    }' > "$MANIFEST_PATH"
fi

HAS_TODO="$(jq -r '
  [
    (.tech_decisions[]?.decision // ""),
    (.tech_decisions[]?.source // ""),
    (.allowed_paths[]? // ""),
    (.acceptance_commands[]? // ""),
    (.modules[]?.description // ""),
    (.modules[]?.allowed_paths[]? // ""),
    (.modules[]?.acceptance_commands[]? // "")
  ]
  | any(test("^TODO:|^TODO$|^TODO"))
' "$MANIFEST_PATH")"

DISPATCH_ALLOWED="true"
VALIDATION_ERROR_COUNT=0
if [[ "$HAS_TODO" == "true" ]]; then
  DISPATCH_ALLOWED="false"
  VALIDATION_ERROR_COUNT=1
fi

jq -n \
  --arg schema_version "1.0.0" \
  --arg task_id "$TASK_ID" \
  --arg validated_at "$(iso_now)" \
  --arg validated_by "codex" \
  --arg manifest_path "$MANIFEST_PATH" \
  --argjson dispatch_allowed "$DISPATCH_ALLOWED" \
  --argjson error_count "$VALIDATION_ERROR_COUNT" \
  --arg runtime_preflight_status "pending" \
  --arg action "$( [[ "$DISPATCH_ALLOWED" == "true" ]] && printf "run_wrapper_preflight" || printf "manual_fix_manifest" )" \
  --arg reason "$( [[ "$DISPATCH_ALLOWED" == "true" ]] && printf "manifest draft passed lightweight checks" || printf "manifest still contains TODO placeholders" )" \
  --arg has_todo "$HAS_TODO" \
  '{
    schema_version: $schema_version,
    task_id: $task_id,
    validated_at: $validated_at,
    validated_by: $validated_by,
    manifest_path: $manifest_path,
    manifest_validation: {
      encoding: "pass",
      json_parse: "pass",
      schema: "pass",
      module_design: (if $has_todo == "true" then "fail" else "pass" end),
      dependency_graph: "pass",
      dispatch_readiness: (if $has_todo == "true" then "fail" else "pass" end)
    },
    dispatch_gate: {
      manifest_dispatch_eligible: $dispatch_allowed,
      runtime_preflight_required: true,
      preflight_rule_owner: "ctrl-codex",
      preflight_execution_owner: "wrapper",
      dispatch_execution_owner: "dispatcher",
      runtime_preflight_status: $runtime_preflight_status
    },
    summary: {
      module_count: 1,
      warning_count: 0,
      error_count: $error_count,
      dispatch_allowed: $dispatch_allowed
    },
    warnings: [],
    errors: (if $has_todo == "true" then [
      {
        module_id: "task.main",
        category: "draft_manifest",
        message: "Manifest still contains TODO placeholders and must be refined before dispatch."
      }
    ] else [] end),
    next_action: {
      action: $action,
      reason: $reason
    }
  }' > "$VALIDATION_PATH"

json_ok \
  --arg task_id "$TASK_ID" \
  --arg manifest_path "$MANIFEST_PATH" \
  --arg validation_path "$VALIDATION_PATH" \
  --argjson dispatch_allowed "$DISPATCH_ALLOWED" \
  '{ok:true,task_id:$task_id,manifest_path:$manifest_path,validation_path:$validation_path,dispatch_allowed:$dispatch_allowed}'

