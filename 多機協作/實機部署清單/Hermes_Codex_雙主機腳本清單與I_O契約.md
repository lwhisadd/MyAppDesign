# Hermes + Codex 雙主機腳本清單與 I/O 契約

> 文件用途：定義 `ctrl-hermes`、`ctrl-codex` 與 worker 之間的固定腳本入口、參數、輸入輸出、產物位置與責任邊界。  
> 適用情境：`ctrl-hermes` 與 `ctrl-codex` 分屬不同主機，並透過 SSH 與固定 task artifact 進行協作。  
> 依據文件：`Hermes_Codex_雙主機實作藍圖.md`、`Hermes_Codex_多機Agent協作最終佈建報告.md`、`codex/REPO_root/AGENTS.md`、`codex/REPO_root/AgentsRule/*`。

---

## 1. 設計目標

本文件只解決介面層問題：

1. 哪些腳本是正式入口。
2. 每支腳本收什麼參數。
3. 每支腳本應讀哪些檔。
4. 每支腳本應產出哪些檔。
5. 每支腳本成功或失敗時，應回傳什麼結構。

本文件**不**取代：

1. `execution manifest` 規格
2. manifest 驗證流程
3. worker 安全限制
4. DB schema 設計

---

## 2. 共同原則

所有正式腳本都必須遵守：

1. 預設編碼一律使用 `UTF-8`。
2. 不接受任意 shell 片段作為輸入。
3. 不接受任意 SQL 作為輸入。
4. 不直接以對話文字當流程依據。
5. 任務識別一律使用 `task_id`。
6. 重要結果必須落地到 task 目錄，不可只印在 stdout。
7. stdout 只輸出簡短、穩定、機器可讀 JSON。
8. stderr 保存診斷訊息，但不得外洩 secrets。

---

## 3. 共同命名與路徑

### 3.1 主機角色

1. `ctrl-hermes`
2. `ctrl-codex`
3. `worker-opencode`
4. `worker-claude`
5. `worker-antigravity`

### 3.2 根目錄

`ctrl-hermes`：

```text
/srv/hermes-control/
```

`ctrl-codex`：

```text
/srv/codex-supervisor/
```

worker：

```text
/srv/agent/
```

### 3.3 Task 目錄

`ctrl-hermes`：

```text
/srv/hermes-control/tasks/TASK-ID/
```

`ctrl-codex`：

```text
/srv/codex-supervisor/results/TASK-ID/
```

worker：

```text
/srv/agent/results/TASK-ID/
```

---

## 4. 共同 task 產物檔名

所有腳本應盡量使用以下固定檔名：

1. `task-envelope.json`
2. `execution-manifest.json`
3. `manifest-validation-result.json`
4. `worker-preflight-result.json`
5. `result.json`
6. `changed-files.txt`
7. `changes.patch`
8. `acceptance.json`
9. `codex-review.json`
10. `codex-review.md`

---

## 5. 正式入口總表

### 5.1 `ctrl-hermes`

1. `task-create-envelope`
2. `task-export-envelope`
3. `task-store-manifest`
4. `task-store-validation`
5. `task-update-phase`
6. `dispatch-task`
7. `task-store-review`
8. `task-get-status`

### 5.2 `ctrl-codex`

1. `plan-task`
2. `review-task`
3. `export-manifest-bundle`
4. `export-review-bundle`

### 5.3 worker

1. `run-opencode`
2. `run-claude`
3. `run-antigravity`
4. `run-codex`

---

## 6. `ctrl-hermes` 腳本契約

### 6.1 `task-create-envelope`

用途：

1. 建立 `task-envelope.json`
2. 初始化 `task_envelopes`
3. 初始化 `task_executions`
4. 建立 Hermes task 目錄

建議位置：

```text
/srv/hermes-control/bin/task-create-envelope
```

呼叫方式：

```bash
task-create-envelope /path/to/request.json
```

輸入：

1. CLI 參數：`request_file`
2. `request_file` 內容應至少包含：
   - `project`
   - `request`
   - `source`
   - `priority`
   - `requires_human_approval`

輸出檔案：

1. `/srv/hermes-control/tasks/TASK-ID/task-envelope.json`

stdout：

```json
{
  "ok": true,
  "task_id": "TASK-20260718-001",
  "task_dir": "/srv/hermes-control/tasks/TASK-20260718-001",
  "envelope_path": "/srv/hermes-control/tasks/TASK-20260718-001/task-envelope.json"
}
```

失敗時：

```json
{
  "ok": false,
  "error": "invalid_request"
}
```

### 6.2 `task-export-envelope`

用途：

1. 讓 `ctrl-hermes` 對 `ctrl-codex` 提供單一 task 的 envelope 匯出入口

呼叫方式：

```bash
task-export-envelope TASK-ID
```

輸入：

1. CLI 參數：`task_id`

輸出：

1. stdout 直接輸出 `task-envelope.json`

限制：

1. 只輸出單一 task 的 envelope
2. 不額外夾帶 DB 內容

### 6.3 `task-store-manifest`

用途：

1. 接收 `ctrl-codex` 規劃完成的 `execution-manifest.json`
2. 保存到 Hermes task 目錄
3. 更新 `task_executions.execution_manifest_path`

呼叫方式：

```bash
task-store-manifest TASK-ID /path/to/execution-manifest.json
```

輸入：

1. CLI 參數：`task_id`
2. CLI 參數：`manifest_file`

輸出檔案：

1. `/srv/hermes-control/tasks/TASK-ID/execution-manifest.json`

stdout：

```json
{
  "ok": true,
  "task_id": "TASK-20260718-001",
  "stored_path": "/srv/hermes-control/tasks/TASK-20260718-001/execution-manifest.json"
}
```

### 6.4 `task-store-validation`

用途：

1. 接收 `manifest-validation-result.json`
2. 保存到 Hermes task 目錄
3. 依 `dispatch_allowed` 更新狀態摘要

呼叫方式：

```bash
task-store-validation TASK-ID /path/to/manifest-validation-result.json
```

輸出檔案：

1. `/srv/hermes-control/tasks/TASK-ID/manifest-validation-result.json`

建議行為：

1. 若 `dispatch_allowed = true`，可將 `task_executions.current_phase` 更新為 `planned`
2. 若 `dispatch_allowed = false`，應標示為 `blocked` 或維持待修狀態

### 6.5 `task-update-phase`

用途：

1. 更新 `task_executions.current_phase`
2. 更新 `task_executions.status`
3. 更新 `updated_at`
4. 必要時更新 `started_at` / `finished_at`

呼叫方式：

```bash
task-update-phase TASK-ID PHASE STATUS
```

允許值：

`PHASE`：

1. `enveloped`
2. `planned`
3. `dispatched`
4. `running`
5. `reviewing`
6. `accepted`
7. `failed`
8. `blocked`

`STATUS`：

1. `queued`
2. `ready`
3. `running`
4. `reviewing`
5. `succeeded`
6. `failed`
7. `blocked`

必須檢查：

1. `task_id` 是否存在
2. phase / status 是否在允許 enum 內
3. 是否真的更新到 1 筆資料

stdout：

```json
{
  "ok": true,
  "task_id": "TASK-20260718-001",
  "phase": "planned",
  "status": "ready"
}
```

### 6.6 `dispatch-task`

用途：

1. 作為 Hermes 對 worker 派工的唯一正式入口
2. 讀取 manifest 與 validation result
3. 呼叫目標 worker wrapper
4. 保存 `worker-preflight-result.json` 與 `result.json`
5. 根據結果更新 phase / status

呼叫方式：

```bash
dispatch-task TASK-ID
```

前置要求：

1. `execution-manifest.json` 已存在
2. `manifest-validation-result.json` 已存在
3. `dispatch_allowed = true`

應產出：

1. `worker-preflight-result.json`
2. `result.json`
3. `worker.stdout`
4. `worker.stderr`
5. `changed-files.txt`
6. `changes.patch`

stdout：

```json
{
  "ok": true,
  "task_id": "TASK-20260718-001",
  "worker_id": "opencode-01",
  "preflight_path": "/srv/hermes-control/tasks/TASK-20260718-001/worker-preflight-result.json",
  "result_path": "/srv/hermes-control/tasks/TASK-20260718-001/result.json"
}
```

### 6.7 `task-store-review`

用途：

1. 接收 `acceptance.json`
2. 接收 `codex-review.json`
3. 接收 `codex-review.md`
4. 保存到 Hermes task 目錄
5. 根據驗收結果更新最終 phase / status

呼叫方式：

```bash
task-store-review TASK-ID /path/to/review-bundle-dir
```

應保存：

1. `acceptance.json`
2. `codex-review.json`
3. `codex-review.md`

### 6.8 `task-get-status`

用途：

1. 對外提供單一 task 的狀態查詢
2. 避免 `ctrl-codex` 直接 query DB

呼叫方式：

```bash
task-get-status TASK-ID
```

stdout：

```json
{
  "task_id": "TASK-20260718-001",
  "phase": "reviewing",
  "status": "running",
  "worker_id": "opencode-01",
  "updated_at": "2026-07-18T09:30:00+00:00"
}
```

---

## 7. `ctrl-codex` 腳本契約

### 7.1 `plan-task`

用途：

1. 接收單一 `task_id`
2. 讀取對應 envelope
3. 分析 repo
4. 產生 `execution-manifest.json`
5. 產生 `manifest-validation-result.json`

建議位置：

```text
/srv/codex-supervisor/bin/plan-task
```

呼叫方式：

```bash
plan-task TASK-ID
```

輸入來源：

1. Hermes 匯出的 `task-envelope.json`
2. 本機 repository clone
3. 現有 `AGENTS.md` 與 `AgentsRule/*`

輸出檔案：

1. `/srv/codex-supervisor/results/TASK-ID/execution-manifest.json`
2. `/srv/codex-supervisor/results/TASK-ID/manifest-validation-result.json`

stdout：

```json
{
  "ok": true,
  "task_id": "TASK-20260718-001",
  "manifest_path": "/srv/codex-supervisor/results/TASK-20260718-001/execution-manifest.json",
  "validation_path": "/srv/codex-supervisor/results/TASK-20260718-001/manifest-validation-result.json",
  "dispatch_allowed": true
}
```

### 7.2 `review-task`

用途：

1. 讀取 task 的 manifest 與 worker 結果
2. 驗證 `allowed_paths`
3. 執行 acceptance commands
4. 產出 review 結果

呼叫方式：

```bash
review-task TASK-ID
```

輸入來源：

1. `execution-manifest.json`
2. `result.json`
3. `changed-files.txt`
4. `changes.patch`
5. `worker.stdout`
6. `worker.stderr`

輸出檔案：

1. `/srv/codex-supervisor/results/TASK-ID/acceptance.json`
2. `/srv/codex-supervisor/results/TASK-ID/codex-review.json`
3. `/srv/codex-supervisor/results/TASK-ID/codex-review.md`

stdout：

```json
{
  "ok": true,
  "task_id": "TASK-20260718-001",
  "review_status": "accepted",
  "acceptance_path": "/srv/codex-supervisor/results/TASK-20260718-001/acceptance.json",
  "review_json_path": "/srv/codex-supervisor/results/TASK-20260718-001/codex-review.json",
  "review_md_path": "/srv/codex-supervisor/results/TASK-20260718-001/codex-review.md"
}
```

### 7.3 `export-manifest-bundle`

用途：

1. 匯出規劃階段所有必要產物

呼叫方式：

```bash
export-manifest-bundle TASK-ID OUTPUT_DIR
```

至少應複製：

1. `execution-manifest.json`
2. `manifest-validation-result.json`

### 7.4 `export-review-bundle`

用途：

1. 匯出驗收階段所有必要產物

呼叫方式：

```bash
export-review-bundle TASK-ID OUTPUT_DIR
```

至少應複製：

1. `acceptance.json`
2. `codex-review.json`
3. `codex-review.md`

---

## 8. Worker wrapper 契約

### 8.1 共同用途

每種 worker wrapper 都必須：

1. 讀取 manifest
2. 讀取 validation result
3. 執行 runtime preflight
4. 若不可用則只產出 `worker-preflight-result.json`
5. 若可用則進入 worktree 執行
6. 產出 `result.json`

### 8.2 共同呼叫方式

```bash
run-<agent> TASK-ID MANIFEST_FILE VALIDATION_FILE OUTPUT_DIR
```

例如：

```bash
run-opencode TASK-20260718-001 \
  /srv/hermes-control/tasks/TASK-20260718-001/execution-manifest.json \
  /srv/hermes-control/tasks/TASK-20260718-001/manifest-validation-result.json \
  /srv/hermes-control/tasks/TASK-20260718-001
```

### 8.3 共同輸出

1. `worker-preflight-result.json`
2. `result.json`
3. `worker.stdout`
4. `worker.stderr`
5. 視情況產出 `changed-files.txt`
6. 視情況產出 `changes.patch`

### 8.4 preflight 失敗時 stdout

```json
{
  "ok": false,
  "task_id": "TASK-20260718-001",
  "stage": "preflight",
  "preflight_path": "/srv/hermes-control/tasks/TASK-20260718-001/worker-preflight-result.json",
  "fallback_recommended": true
}
```

### 8.5 執行成功時 stdout

```json
{
  "ok": true,
  "task_id": "TASK-20260718-001",
  "result_path": "/srv/hermes-control/tasks/TASK-20260718-001/result.json",
  "commit_sha": "0123456789abcdef"
}
```

---

## 9. 建議 JSON 契約

### 9.1 `task-create-envelope` 輸入檔

```json
{
  "project": "YOUR_REPO",
  "request": "新增訂單查詢 API 並補測試",
  "source": "telegram",
  "priority": "normal",
  "requires_human_approval": false,
  "created_by": "telegram:user123"
}
```

### 9.2 `plan-task` 成功 stdout

```json
{
  "ok": true,
  "task_id": "TASK-20260718-001",
  "dispatch_allowed": true
}
```

### 9.3 `review-task` 成功 stdout

```json
{
  "ok": true,
  "task_id": "TASK-20260718-001",
  "review_status": "accepted"
}
```

---

## 10. Exit code 建議

所有自製腳本建議統一：

1. `0`：成功
2. `10`：輸入參數錯誤
3. `11`：task 不存在
4. `12`：檔案缺失
5. `13`：JSON 結構錯誤
6. `14`：狀態不允許
7. `15`：寫入失敗
8. `16`：SSH / 遠端呼叫失敗
9. `17`：驗證失敗

worker wrapper 的 agent-specific exit code，仍應遵守既有文件中的 70-85 區間。

---

## 11. 推薦同步方式

推薦使用：

1. `ssh` 執行固定命令
2. `scp` 複製單一檔案
3. `rsync` 同步單一 task 目錄

不推薦：

1. 共享資料夾即時同步 worktree
2. 讓 `ctrl-codex` 直接 mount Hermes DB 路徑
3. 讓 worker 直接寫回 Hermes DB

---

## 12. MVP 最小腳本組合

若要先做最小可行版，只要先完成以下 6 支：

`ctrl-hermes`：

1. `task-create-envelope`
2. `task-store-manifest`
3. `task-update-phase`
4. `dispatch-task`

`ctrl-codex`：

1. `plan-task`
2. `review-task`

worker：

1. `run-opencode`

---

## 13. 第一輪端到端測試路徑

建議先跑以下順序：

1. `task-create-envelope`
2. `task-export-envelope`
3. `plan-task`
4. `task-store-manifest`
5. `task-store-validation`
6. `dispatch-task`
7. `review-task`
8. `task-store-review`
9. `task-get-status`

驗收標準：

1. 每一步都有 JSON stdout
2. 每一步的核心產物都落地
3. phase / status 只由 `ctrl-hermes` 收斂
4. `ctrl-codex` 全程不需直接打 DB

---

## 14. 一句話定案

```text
雙主機實作不是互相開放權限
而是用固定腳本交換固定產物
讓 ctrl-hermes 控制流程
讓 ctrl-codex 提供工程判斷
```

