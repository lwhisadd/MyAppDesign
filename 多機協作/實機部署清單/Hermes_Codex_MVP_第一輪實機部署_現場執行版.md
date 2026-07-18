# Hermes + Codex MVP 第一輪實機部署 現場執行版

> 用途：提供可直接照貼執行的第一輪部署與 dry-run 測試步驟。  
> 日期：2026-07-18  
> 適用主機：`ctrl-hermes`、`ctrl-codex`、`worker-opencode`

---

## 1. 先替換這些變數

先把下列值換成你的真實環境：

```text
HERMES_USER=hermesctl
CODEX_USER=codexctl
WORKER_USER=agentworker
PROJECT_NAME=YOUR_REPO
REPO_SSH_URL=git@github.com:YOUR_ORG/YOUR_REPO.git
TASK_ID_EXAMPLE=TASK-20260718-001
```

如果你的帳號不是上面這些名字，後面所有命令都要一起替換。

---

## 2. `ctrl-hermes`：建立目錄與放腳本

在 `ctrl-hermes` 執行：

```bash
sudo mkdir -p /srv/hermes-control/bin
sudo mkdir -p /srv/hermes-control/tasks
sudo mkdir -p /srv/hermes-control/state
sudo chown -R hermesctl:hermesctl /srv/hermes-control
chmod 700 /srv/hermes-control/bin
chmod 700 /srv/hermes-control/tasks
```

把下列檔案複製到 `ctrl-hermes`：

```text
/srv/hermes-control/bin/common.sh
/srv/hermes-control/bin/task-create-envelope.sh
/srv/hermes-control/bin/task-store-manifest.sh
/srv/hermes-control/bin/task-update-phase.sh
/srv/hermes-control/bin/dispatch-task.sh
```

設定權限：

```bash
chmod 750 /srv/hermes-control/bin/*.sh
```

檢查工具：

```bash
command -v bash
command -v jq
command -v sqlite3
```

預期：三個指令都能找到路徑。

---

## 3. `ctrl-codex`：建立目錄與放腳本

在 `ctrl-codex` 執行：

```bash
sudo mkdir -p /srv/codex-supervisor/bin
sudo mkdir -p /srv/codex-supervisor/tasks
sudo mkdir -p /srv/codex-supervisor/results
sudo mkdir -p /srv/codex-supervisor/worktrees
sudo mkdir -p /srv/codex-supervisor/repos
sudo chown -R codexctl:codexctl /srv/codex-supervisor
chmod 700 /srv/codex-supervisor/bin
chmod 700 /srv/codex-supervisor/tasks
chmod 700 /srv/codex-supervisor/results
```

把下列檔案複製到 `ctrl-codex`：

```text
/srv/codex-supervisor/bin/common.sh
/srv/codex-supervisor/bin/plan-task.sh
/srv/codex-supervisor/bin/review-task.sh
```

設定權限：

```bash
chmod 750 /srv/codex-supervisor/bin/*.sh
```

建立 repo clone：

```bash
git clone git@github.com:YOUR_ORG/YOUR_REPO.git /srv/codex-supervisor/repos/YOUR_REPO
```

檢查工具：

```bash
command -v bash
command -v jq
command -v git
```

---

## 4. `worker-opencode`：建立目錄與放腳本

在 `worker-opencode` 執行：

```bash
sudo mkdir -p /srv/agent/bin
sudo mkdir -p /srv/agent/repos
sudo mkdir -p /srv/agent/worktrees
sudo mkdir -p /srv/agent/results
sudo chown -R agentworker:agentworker /srv/agent
chmod 700 /srv/agent/bin
chmod 700 /srv/agent/worktrees
chmod 700 /srv/agent/results
```

把下列檔案複製到 `worker-opencode`：

```text
/srv/agent/bin/common.sh
/srv/agent/bin/run-opencode.sh
```

設定權限：

```bash
chmod 750 /srv/agent/bin/*.sh
```

建立 repo clone：

```bash
git clone git@github.com:YOUR_ORG/YOUR_REPO.git /srv/agent/repos/YOUR_REPO
```

這一輪先維持 dry-run，不要設定：

```bash
export OPENCODE_DRY_RUN=0
```

---

## 5. 連線先測通

在 `ctrl-hermes` 執行：

```bash
ssh codexctl@ctrl-codex 'hostname'
ssh agentworker@worker-opencode 'hostname'
```

預期：都能回主機名。

如果失敗，先停在這裡修 SSH，不要往後做。

---

## 6. 建立測試 request

在 `ctrl-hermes` 執行：

```bash
cat > /tmp/request.json <<'EOF'
{
  "project": "YOUR_REPO",
  "request": "建立 MVP task flow dry-run 測試",
  "source": "manual",
  "priority": "normal",
  "requires_human_approval": false,
  "created_by": "manual:test"
}
EOF
```

把 `YOUR_REPO` 換成真實 repo 名稱。

---

## 7. 建立 task envelope

在 `ctrl-hermes` 執行：

```bash
/srv/hermes-control/bin/task-create-envelope.sh /tmp/request.json
```

預期 stdout 類似：

```json
{
  "ok": true,
  "task_id": "TASK-20260718-001",
  "task_dir": "/srv/hermes-control/tasks/TASK-20260718-001",
  "envelope_path": "/srv/hermes-control/tasks/TASK-20260718-001/task-envelope.json"
}
```

記下 `task_id`，以下用：

```text
TASK-20260718-001
```

驗證 DB：

```bash
sqlite3 -json /srv/hermes-control/state/coordination.db \
  "SELECT task_id, current_phase, status FROM task_executions ORDER BY rowid DESC LIMIT 1;"
```

預期：

1. `current_phase = enveloped`
2. `status = queued`

---

## 8. 把 envelope 複製到 `ctrl-codex`

在 `ctrl-codex` 先建目錄：

```bash
mkdir -p /srv/codex-supervisor/tasks/TASK-20260718-001
```

在 `ctrl-hermes` 執行：

```bash
scp /srv/hermes-control/tasks/TASK-20260718-001/task-envelope.json \
  codexctl@ctrl-codex:/srv/codex-supervisor/tasks/TASK-20260718-001/task-envelope.json
```

---

## 9. 在 `ctrl-codex` 跑 `plan-task`

在 `ctrl-codex` 執行：

```bash
/srv/codex-supervisor/bin/plan-task.sh TASK-20260718-001
```

預期產物：

```text
/srv/codex-supervisor/results/TASK-20260718-001/execution-manifest.json
/srv/codex-supervisor/results/TASK-20260718-001/manifest-validation-result.json
```

先看結果：

```bash
cat /srv/codex-supervisor/results/TASK-20260718-001/manifest-validation-result.json | jq
```

第一輪預期大機率是：

```json
"dispatch_allowed": false
```

這是正常的，因為骨架 manifest 預設含 `TODO`。

---

## 10. 拉回 manifest 到 `ctrl-hermes`

在 `ctrl-hermes` 執行：

```bash
mkdir -p /tmp/TASK-20260718-001

scp codexctl@ctrl-codex:/srv/codex-supervisor/results/TASK-20260718-001/execution-manifest.json \
  /tmp/TASK-20260718-001/execution-manifest.json

scp codexctl@ctrl-codex:/srv/codex-supervisor/results/TASK-20260718-001/manifest-validation-result.json \
  /tmp/TASK-20260718-001/manifest-validation-result.json
```

保存 manifest：

```bash
/srv/hermes-control/bin/task-store-manifest.sh \
  TASK-20260718-001 \
  /tmp/TASK-20260718-001/execution-manifest.json
```

第一輪先手動放 validation 檔：

```bash
cp /tmp/TASK-20260718-001/manifest-validation-result.json \
  /srv/hermes-control/tasks/TASK-20260718-001/manifest-validation-result.json
```

---

## 11. 手動細化 manifest

如果 `dispatch_allowed` 是 `false`，在 `ctrl-codex` 手動修改：

```text
/srv/codex-supervisor/results/TASK-20260718-001/execution-manifest.json
```

至少把這些 `TODO` 改掉：

1. `tech_decisions[].decision`
2. `tech_decisions[].source`
3. `allowed_paths`
4. `acceptance_commands`
5. `modules[].description`
6. `modules[].allowed_paths`
7. `modules[].acceptance_commands`

改完後重跑：

```bash
/srv/codex-supervisor/bin/plan-task.sh TASK-20260718-001
```

直到：

```bash
cat /srv/codex-supervisor/results/TASK-20260718-001/manifest-validation-result.json | jq '.summary.dispatch_allowed'
```

預期變成：

```json
true
```

再重新拉回 Hermes 並覆蓋：

```bash
scp codexctl@ctrl-codex:/srv/codex-supervisor/results/TASK-20260718-001/execution-manifest.json \
  /tmp/TASK-20260718-001/execution-manifest.json

scp codexctl@ctrl-codex:/srv/codex-supervisor/results/TASK-20260718-001/manifest-validation-result.json \
  /tmp/TASK-20260718-001/manifest-validation-result.json

/srv/hermes-control/bin/task-store-manifest.sh \
  TASK-20260718-001 \
  /tmp/TASK-20260718-001/execution-manifest.json

cp /tmp/TASK-20260718-001/manifest-validation-result.json \
  /srv/hermes-control/tasks/TASK-20260718-001/manifest-validation-result.json
```

---

## 12. 先檢查 `dispatch-task.sh` 的 worker 呼叫方式

目前骨架版 `dispatch-task.sh` 預設會找：

```text
/srv/agent/bin/run-opencode
```

這在真實雙主機通常不對，因為那是 worker 主機上的路徑。  
第一輪上機前，請先把 `dispatch-task.sh` 改成透過 SSH 呼叫 worker，例如概念上改成：

```bash
ssh agentworker@worker-opencode \
  /srv/agent/bin/run-opencode.sh TASK-ID MANIFEST VALIDATION OUTPUT_DIR
```

如果你還沒改這一段，`dispatch-task.sh` 很可能會卡在找不到 wrapper。

---

## 13. 跑第一次 dispatch dry-run

在 `ctrl-hermes` 執行：

```bash
/srv/hermes-control/bin/dispatch-task.sh TASK-20260718-001
```

預期至少會生成：

```text
/srv/hermes-control/tasks/TASK-20260718-001/worker-preflight-result.json
/srv/hermes-control/tasks/TASK-20260718-001/result.json
```

檢查：

```bash
cat /srv/hermes-control/tasks/TASK-20260718-001/worker-preflight-result.json | jq
cat /srv/hermes-control/tasks/TASK-20260718-001/result.json | jq
```

如果 dry-run 成功，通常會看到：

1. `preflight.available = true`
2. `result.status = "completed"`

檢查 phase：

```bash
sqlite3 -json /srv/hermes-control/state/coordination.db \
  "SELECT task_id, current_phase, status FROM task_executions WHERE task_id='TASK-20260718-001';"
```

預期：

1. `current_phase = reviewing`
2. `status = reviewing`

---

## 14. 把結果交給 `ctrl-codex`

在 `ctrl-codex` 先確保：

```bash
mkdir -p /srv/codex-supervisor/results/TASK-20260718-001
```

在 `ctrl-hermes` 執行：

```bash
scp /srv/hermes-control/tasks/TASK-20260718-001/result.json \
  codexctl@ctrl-codex:/srv/codex-supervisor/results/TASK-20260718-001/result.json
```

如果存在，也一起帶過去：

```bash
scp /srv/hermes-control/tasks/TASK-20260718-001/changed-files.txt \
  codexctl@ctrl-codex:/srv/codex-supervisor/results/TASK-20260718-001/changed-files.txt

scp /srv/hermes-control/tasks/TASK-20260718-001/changes.patch \
  codexctl@ctrl-codex:/srv/codex-supervisor/results/TASK-20260718-001/changes.patch
```

確認 `execution-manifest.json` 也在 `ctrl-codex` 的結果目錄。

---

## 15. 在 `ctrl-codex` 跑 review

在 `ctrl-codex` 執行：

```bash
/srv/codex-supervisor/bin/review-task.sh TASK-20260718-001
```

預期產物：

```text
/srv/codex-supervisor/results/TASK-20260718-001/acceptance.json
/srv/codex-supervisor/results/TASK-20260718-001/codex-review.json
/srv/codex-supervisor/results/TASK-20260718-001/codex-review.md
```

第一輪重點：

1. 有產物就算成功
2. 不要求 `accepted`
3. dry-run 下 acceptance 失敗或 `not_run` 都可以接受

---

## 16. 把 review 拉回 `ctrl-hermes`

在 `ctrl-hermes` 執行：

```bash
mkdir -p /tmp/TASK-20260718-001-review

scp codexctl@ctrl-codex:/srv/codex-supervisor/results/TASK-20260718-001/acceptance.json \
  /tmp/TASK-20260718-001-review/acceptance.json

scp codexctl@ctrl-codex:/srv/codex-supervisor/results/TASK-20260718-001/codex-review.json \
  /tmp/TASK-20260718-001-review/codex-review.json

scp codexctl@ctrl-codex:/srv/codex-supervisor/results/TASK-20260718-001/codex-review.md \
  /tmp/TASK-20260718-001-review/codex-review.md

cp /tmp/TASK-20260718-001-review/acceptance.json \
  /srv/hermes-control/tasks/TASK-20260718-001/acceptance.json

cp /tmp/TASK-20260718-001-review/codex-review.json \
  /srv/hermes-control/tasks/TASK-20260718-001/codex-review.json

cp /tmp/TASK-20260718-001-review/codex-review.md \
  /srv/hermes-control/tasks/TASK-20260718-001/codex-review.md
```

---

## 17. 第一輪成功判定

這輪只要達成以下 7 件事就算成功：

1. task 建起來了
2. DB 有 phase / status
3. manifest 有生成
4. validation 有生成
5. dispatch 有生成 preflight / result
6. review 有生成 acceptance / review 檔
7. 三台主機之間 artifact 能往返

---

## 18. 這輪做完後立刻補

建議下一批就補：

1. `task-store-validation.sh`
2. `task-store-review.sh`
3. `task-export-envelope.sh`
4. `task-get-status.sh`
5. `dispatch-task.sh` 經 SSH 呼叫 worker wrapper
6. `plan-task.sh` 直接引用正式 template

---

## 19. 最短版順序

如果你只要最短操作順序，就照這串做：

1. 三台主機放腳本
2. `task-create-envelope.sh`
3. `scp envelope -> ctrl-codex`
4. `plan-task.sh`
5. 手動修 manifest 到 `dispatch_allowed=true`
6. 拉回 manifest + validation
7. `dispatch-task.sh`
8. `scp result -> ctrl-codex`
9. `review-task.sh`
10. 拉回 review 產物

