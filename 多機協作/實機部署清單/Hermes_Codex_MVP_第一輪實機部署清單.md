# Hermes + Codex MVP 第一輪實機部署清單

> 文件用途：提供 `ctrl-hermes`、`ctrl-codex`、`worker-opencode` 三台主機的第一輪實機部署步驟，讓 `mvp_shell` 骨架可以先跑出 dry-run 等級的端到端閉環。  
> 適用範圍：SQLite 狀態庫已建立，並採用 `多機協作/mvp_shell` 內的第一版 shell skeleton。  
> 文件日期：2026-07-18

---

## 1. 本輪目標

這一輪不是要上正式生產，而是要先驗證：

1. `ctrl-hermes` 能建立 task 並寫入 DB
2. `ctrl-hermes` 能把 task artifact 傳給 `ctrl-codex`
3. `ctrl-codex` 能產生 manifest 與 validation result
4. `ctrl-hermes` 能透過 `dispatch-task.sh` 呼叫 `worker-opencode`
5. `worker-opencode` 能回傳 preflight/result
6. `ctrl-codex` 能完成 review
7. 所有核心產物都能落地

本輪預期成果是：

1. 成功跑完 dry-run 閉環
2. 先不要求真正執行 `opencode`
3. 先不要求真實多 worker fallback
4. 先不要求完整通知與 webhook

---

## 2. 部署前確認

三台主機：

1. `ctrl-hermes`
2. `ctrl-codex`
3. `worker-opencode`

請先確認：

1. 三台都在同一個 Tailscale 私網
2. `ctrl-hermes` 可 SSH 到 `ctrl-codex`
3. `ctrl-hermes` 可 SSH 到 `worker-opencode`
4. `jq`、`bash`、`git` 已安裝
5. `ctrl-hermes` 已有 `/srv/hermes-control/state/coordination.db`

建議先測：

```bash
ssh codexctl@ctrl-codex 'hostname'
ssh agentworker@worker-opencode 'hostname'
```

如果這一步過不了，先不要進行後續腳本部署。

---

## 3. 本輪會用到的檔案

來源目錄：

[`mvp_shell`](</D:/test/opencode/MyAppDesign/多機協作/mvp_shell>)

會用到：

1. [`common.sh`](</D:/test/opencode/MyAppDesign/多機協作/mvp_shell/common.sh>)
2. [`ctrl-hermes/task-create-envelope.sh`](</D:/test/opencode/MyAppDesign/多機協作/mvp_shell/ctrl-hermes/task-create-envelope.sh>)
3. [`ctrl-hermes/task-store-manifest.sh`](</D:/test/opencode/MyAppDesign/多機協作/mvp_shell/ctrl-hermes/task-store-manifest.sh>)
4. [`ctrl-hermes/task-update-phase.sh`](</D:/test/opencode/MyAppDesign/多機協作/mvp_shell/ctrl-hermes/task-update-phase.sh>)
5. [`ctrl-hermes/dispatch-task.sh`](</D:/test/opencode/MyAppDesign/多機協作/mvp_shell/ctrl-hermes/dispatch-task.sh>)
6. [`ctrl-codex/plan-task.sh`](</D:/test/opencode/MyAppDesign/多機協作/mvp_shell/ctrl-codex/plan-task.sh>)
7. [`ctrl-codex/review-task.sh`](</D:/test/opencode/MyAppDesign/多機協作/mvp_shell/ctrl-codex/review-task.sh>)
8. [`worker-opencode/run-opencode.sh`](</D:/test/opencode/MyAppDesign/多機協作/mvp_shell/worker-opencode/run-opencode.sh>)

---

## 4. `ctrl-hermes` 佈署步驟

以下在 `ctrl-hermes` 執行。

### 4.1 建立目錄

```bash
sudo mkdir -p /srv/hermes-control/bin
sudo mkdir -p /srv/hermes-control/tasks
sudo mkdir -p /srv/hermes-control/state
sudo chown -R hermesctl:hermesctl /srv/hermes-control
chmod 700 /srv/hermes-control/bin
chmod 700 /srv/hermes-control/tasks
```

如果你實際帳號不是 `hermesctl`，請改成真實帳號。

### 4.2 複製腳本

將以下檔案放到 `ctrl-hermes`：

1. `common.sh`
2. `task-create-envelope.sh`
3. `task-store-manifest.sh`
4. `task-update-phase.sh`
5. `dispatch-task.sh`

建議目標位置：

```text
/srv/hermes-control/bin/common.sh
/srv/hermes-control/bin/task-create-envelope.sh
/srv/hermes-control/bin/task-store-manifest.sh
/srv/hermes-control/bin/task-update-phase.sh
/srv/hermes-control/bin/dispatch-task.sh
```

### 4.3 設定權限

```bash
chmod 750 /srv/hermes-control/bin/*.sh
```

### 4.4 驗證工具存在

```bash
command -v bash
command -v jq
command -v sqlite3
```

---

## 5. `ctrl-codex` 佈署步驟

以下在 `ctrl-codex` 執行。

### 5.1 建立目錄

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

如果你實際帳號不是 `codexctl`，請改成真實帳號。

### 5.2 複製腳本

將以下檔案放到 `ctrl-codex`：

1. `common.sh`
2. `plan-task.sh`
3. `review-task.sh`

建議目標位置：

```text
/srv/codex-supervisor/bin/common.sh
/srv/codex-supervisor/bin/plan-task.sh
/srv/codex-supervisor/bin/review-task.sh
```

### 5.3 設定權限

```bash
chmod 750 /srv/codex-supervisor/bin/*.sh
```

### 5.4 放置 repository clone

這批腳本預設 repo 路徑為：

```text
/srv/codex-supervisor/repos/YOUR_REPO
```

請先準備真實 repo clone，例如：

```bash
git clone git@github.com:YOUR_ORG/YOUR_REPO.git /srv/codex-supervisor/repos/YOUR_REPO
```

如果 repo 名稱不是 `YOUR_REPO`，後續測試資料也要一致替換。

---

## 6. `worker-opencode` 佈署步驟

以下在 `worker-opencode` 執行。

### 6.1 建立目錄

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

### 6.2 複製腳本

將以下檔案放到 `worker-opencode`：

1. `common.sh`
2. `run-opencode.sh`

建議目標位置：

```text
/srv/agent/bin/common.sh
/srv/agent/bin/run-opencode.sh
```

### 6.3 設定權限

```bash
chmod 750 /srv/agent/bin/*.sh
```

### 6.4 放置 repository clone

這批腳本預設 repo 路徑為：

```text
/srv/agent/repos/YOUR_REPO
```

請先準備同一份 repo clone：

```bash
git clone git@github.com:YOUR_ORG/YOUR_REPO.git /srv/agent/repos/YOUR_REPO
```

### 6.5 保持 dry-run

本輪先不要切到真實 `opencode` 執行。  
也就是說：

1. 不要設定 `OPENCODE_DRY_RUN=0`
2. 讓 `run-opencode.sh` 先走 dry-run 模式

---

## 7. 第一輪測試資料

在 `ctrl-hermes` 建立一份測試 request：

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

請把 `YOUR_REPO` 換成真實 repo 名稱。

---

## 8. Step 1：建立 task envelope

在 `ctrl-hermes` 執行：

```bash
/srv/hermes-control/bin/task-create-envelope.sh /tmp/request.json
```

預期：

1. stdout 回 JSON
2. 產生 `TASK-YYYYMMDD-NNN`
3. 產生：

```text
/srv/hermes-control/tasks/TASK-ID/task-envelope.json
```

4. DB 內新增：
   - `task_envelopes`
   - `task_executions`

建議立即驗證：

```bash
sqlite3 -json /srv/hermes-control/state/coordination.db \
  "SELECT task_id, current_phase, status FROM task_executions ORDER BY rowid DESC LIMIT 1;"
```

---

## 9. Step 2：把 envelope 交給 `ctrl-codex`

假設剛拿到：

```text
TASK-20260718-001
```

在 `ctrl-codex` 先建立 task input 目錄：

```bash
mkdir -p /srv/codex-supervisor/tasks/TASK-20260718-001
```

由 `ctrl-hermes` 複製：

```bash
scp /srv/hermes-control/tasks/TASK-20260718-001/task-envelope.json \
  codexctl@ctrl-codex:/srv/codex-supervisor/tasks/TASK-20260718-001/task-envelope.json
```

---

## 10. Step 3：在 `ctrl-codex` 跑 `plan-task`

在 `ctrl-codex` 執行：

```bash
/srv/codex-supervisor/bin/plan-task.sh TASK-20260718-001
```

預期：

1. 產生：
   - `/srv/codex-supervisor/results/TASK-20260718-001/execution-manifest.json`
   - `/srv/codex-supervisor/results/TASK-20260718-001/manifest-validation-result.json`
2. 因為預設 manifest 含 `TODO`，所以：
   - `dispatch_allowed` 很可能是 `false`

這是正常的，因為骨架在保護你，不讓未細化 manifest 直接派工。

---

## 11. Step 4：把 manifest 帶回 `ctrl-hermes`

在 `ctrl-hermes` 拉回：

```bash
mkdir -p /tmp/TASK-20260718-001

scp codexctl@ctrl-codex:/srv/codex-supervisor/results/TASK-20260718-001/execution-manifest.json \
  /tmp/TASK-20260718-001/execution-manifest.json

scp codexctl@ctrl-codex:/srv/codex-supervisor/results/TASK-20260718-001/manifest-validation-result.json \
  /tmp/TASK-20260718-001/manifest-validation-result.json
```

然後先保存 manifest：

```bash
/srv/hermes-control/bin/task-store-manifest.sh \
  TASK-20260718-001 \
  /tmp/TASK-20260718-001/execution-manifest.json
```

注意：

1. 目前骨架中還沒另外提供 `task-store-validation.sh`
2. 第一輪可先手動複製 validation 檔到 task 目錄：

```bash
cp /tmp/TASK-20260718-001/manifest-validation-result.json \
  /srv/hermes-control/tasks/TASK-20260718-001/manifest-validation-result.json
```

---

## 12. Step 5：細化 manifest 後再放行派工

因為 `plan-task.sh` 預設會生成帶 `TODO` 的 manifest，所以要先在 `ctrl-codex` 手動修改：

1. `tech_decisions`
2. `allowed_paths`
3. `acceptance_commands`
4. `modules[].allowed_paths`
5. `modules[].acceptance_commands`
6. 其他 `TODO`

然後重跑：

```bash
/srv/codex-supervisor/bin/plan-task.sh TASK-20260718-001
```

直到 `manifest-validation-result.json` 顯示：

```json
"dispatch_allowed": true
```

再重新拉回 Hermes。

---

## 13. Step 6：在 `worker-opencode` 放置 wrapper

這一步只要確認：

1. `/srv/agent/bin/run-opencode.sh` 可執行
2. `/srv/agent/repos/YOUR_REPO` 存在
3. `dispatch-task.sh` 裡的 `WORKER_OPENCODE_BIN` 能找到 wrapper

如果 `dispatch-task.sh` 是直接在 `ctrl-hermes` 本機呼叫 wrapper，你就需要改成：

1. 透過 `ssh agentworker@worker-opencode ...`
2. 或先做一個本機 wrapper proxy

這是第一輪最需要你依現場補的地方。

建議做法：

1. 先把 `dispatch-task.sh` 改成經 SSH 呼叫 worker wrapper
2. 不要假設 `ctrl-hermes` 本機就有 `/srv/agent/bin/run-opencode`

---

## 14. Step 7：第一次 dispatch dry-run

當 validation 已通過後，在 `ctrl-hermes` 執行：

```bash
/srv/hermes-control/bin/dispatch-task.sh TASK-20260718-001
```

預期：

1. 產生：
   - `worker-preflight-result.json`
   - `result.json`
   - `worker.stdout`
   - `worker.stderr`
2. phase 被更新成：
   - `reviewing`，如果 result 是 `completed`
   - `blocked`，如果 preflight 失敗
   - `failed`，如果 wrapper 回一般失敗

---

## 15. Step 8：把 worker 結果交給 `ctrl-codex`

在 `ctrl-codex` 建立結果目錄：

```bash
mkdir -p /srv/codex-supervisor/results/TASK-20260718-001
```

由 `ctrl-hermes` 複製：

```bash
scp /srv/hermes-control/tasks/TASK-20260718-001/result.json \
  codexctl@ctrl-codex:/srv/codex-supervisor/results/TASK-20260718-001/result.json
```

若存在，也一起帶過去：

```bash
scp /srv/hermes-control/tasks/TASK-20260718-001/changed-files.txt \
  codexctl@ctrl-codex:/srv/codex-supervisor/results/TASK-20260718-001/changed-files.txt

scp /srv/hermes-control/tasks/TASK-20260718-001/changes.patch \
  codexctl@ctrl-codex:/srv/codex-supervisor/results/TASK-20260718-001/changes.patch
```

同時確保：

1. `execution-manifest.json` 也在 `ctrl-codex` 的結果目錄

---

## 16. Step 9：在 `ctrl-codex` 跑 review

在 `ctrl-codex` 執行：

```bash
/srv/codex-supervisor/bin/review-task.sh TASK-20260718-001
```

預期產物：

1. `acceptance.json`
2. `codex-review.json`
3. `codex-review.md`

注意：

1. 因為目前 worker 是 dry-run，很多 acceptance command 會失敗或 `not_run`
2. 第一輪的目標不是 review accepted，而是確認 review 流程能產生檔案

---

## 17. Step 10：回寫 review 並收斂狀態

第一輪你可以先手動把 review 產物拉回 `ctrl-hermes`：

```bash
mkdir -p /tmp/TASK-20260718-001-review

scp codexctl@ctrl-codex:/srv/codex-supervisor/results/TASK-20260718-001/acceptance.json \
  /tmp/TASK-20260718-001-review/acceptance.json

scp codexctl@ctrl-codex:/srv/codex-supervisor/results/TASK-20260718-001/codex-review.json \
  /tmp/TASK-20260718-001-review/codex-review.json

scp codexctl@ctrl-codex:/srv/codex-supervisor/results/TASK-20260718-001/codex-review.md \
  /tmp/TASK-20260718-001-review/codex-review.md
```

再手動複製到：

```text
/srv/hermes-control/tasks/TASK-20260718-001/
```

第一輪可先人工決定是否下：

```bash
/srv/hermes-control/bin/task-update-phase.sh TASK-20260718-001 failed failed
```

或若你只是驗證流程，可以先保持在 `reviewing`。

---

## 18. 第一輪驗收標準

這輪只要滿足以下條件，就算成功：

1. `task-create-envelope.sh` 成功寫 DB
2. `plan-task.sh` 成功產生 manifest 與 validation result
3. `task-store-manifest.sh` 成功落地 manifest
4. `dispatch-task.sh` 成功產生 preflight/result
5. `review-task.sh` 成功產生 acceptance/review 檔
6. 三台主機間 artifact 能手動傳遞
7. `ctrl-codex` 全程不需直接打 Hermes DB

---

## 19. 第一輪後立刻要補的缺口

跑完後建議立刻補：

1. `task-store-validation.sh`
2. `task-store-review.sh`
3. `task-export-envelope.sh`
4. `task-get-status.sh`
5. `dispatch-task.sh` 透過 SSH 呼叫 worker wrapper
6. `plan-task.sh` 改成引用真實 manifest template，而不是帶 `TODO` 的草稿生成

---

## 20. 一句話定案

```text
第一輪實機部署的重點
不是一次做完全部自動化
而是先讓三台主機之間
能安全交換 artifact
並跑通一個 dry-run 閉環
```

