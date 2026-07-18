# MVP Shell Skeletons

This directory contains first-version shell skeletons for the dual-host MVP:

1. `ctrl-hermes`
2. `ctrl-codex`
3. `worker-opencode`

These scripts are designed to:

1. match the file and JSON contracts in `Hermes_Codex_雙主機腳本清單與I_O契約.md`
2. be copied to the target hosts and adjusted in place
3. keep the control-plane / planning / worker boundaries explicit

They are intentionally conservative:

1. `plan-task.sh` can emit a draft manifest that still blocks dispatch
2. `run-opencode.sh` defaults to dry-run mode unless `OPENCODE_DRY_RUN=0`
3. no script accepts arbitrary SQL or arbitrary shell commands as input

## Layout

```text
mvp_shell/
├── common.sh
├── ctrl-hermes/
│   ├── dispatch-task.sh
│   ├── task-create-envelope.sh
│   ├── task-store-manifest.sh
│   └── task-update-phase.sh
├── ctrl-codex/
│   ├── plan-task.sh
│   └── review-task.sh
└── worker-opencode/
    └── run-opencode.sh
```

## Default paths

Hermes host:

```text
/srv/hermes-control
```

Codex host:

```text
/srv/codex-supervisor
```

Worker host:

```text
/srv/agent
```

Most paths can be overridden with environment variables defined in `common.sh`.

## Required tools

The skeletons assume:

1. `bash`
2. `jq`
3. `sqlite3` on `ctrl-hermes`
4. `git` on `ctrl-codex` and worker

## Suggested first rollout

1. copy `common.sh` and the relevant host folder to each target host
2. `chmod 750` the scripts
3. test `task-create-envelope.sh`
4. test `plan-task.sh`
5. test `dispatch-task.sh`
6. test `review-task.sh`

## Important note

These are scaffolds, not final production scripts. They are meant to reduce
bootstrap time and make the first end-to-end flow concrete.

