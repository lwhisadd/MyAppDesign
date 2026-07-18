# Hermes + Codex 雙主機實作藍圖

> 文件用途：將 `ctrl-hermes` 與 `ctrl-codex` 的分工、連線方式、共享資訊與實作步驟落成為可直接施工的雙主機藍圖。  
> 適用情境：Hermes 控制平面與 Codex 工程主管分別部署在兩台不同主機。  
> 依據文件：`Hermes_Codex_多機Agent協作最終佈建報告.md`、`codex/REPO_root/AGENTS.md`、`codex/REPO_root/AgentsRule/*`、`worker/*`。

---

## 1. 目標

本藍圖要解決四件事：

1. 定義 `ctrl-hermes` 與 `ctrl-codex` 誰主導、誰連誰。
2. 定義兩台主機之間只共享哪些任務事實與工程產物。
3. 定義固定入口腳本與 task 目錄結構，避免任意 SSH 與任意 SQL。
4. 定義從 `task envelope` 到驗收結束的完整雙主機工作流。

---

## 2. 角色定位

### 2.1 `ctrl-hermes`

`ctrl-hermes` 是控制平面主機，負責：

1. 接收使用者請求或外部入口事件。
2. 建立 `task envelope`。
3. 保存 SQLite / PostgreSQL 狀態資料庫。
4. 控制排程、通知、人工核准、重試、fallback、cooldown。
5. 透過固定 Dispatcher / SSH 入口呼叫 `ctrl-codex` 與各 worker。
6. 保存 task 最終產物副本或主副本。

### 2.2 `ctrl-codex`

`ctrl-codex` 是工程規劃與驗收主機，負責：

1. 讀取 repository 與 `task envelope`。
2. 產生 `execution manifest`。
3. 驗證 manifest。
4. 制定 `dispatch_policy` 與 preflight 規則。
5. 對 worker 結果做最終驗收。
6. 產出 `codex-review.json` 與 `codex-review.md`。

### 2.3 Worker

Worker 是執行層，負責：

1. 根據 manifest 施工。
2. 只在指定 worktree 內修改 `allowed_paths`。
3. 回傳 `result.json`、stdout / stderr、patch、commit SHA。

---

## 3. 主導關係

雙主機部署時，**控制權應在 `ctrl-hermes`，不是 `ctrl-codex`**。

原因：

1. `ctrl-hermes` 持有任務真實狀態來源。
2. `ctrl-hermes` 需要協調通知、人工核准、排程、重試與 cooldown。
3. `ctrl-codex` 雖然負責工程判斷，但不應直接成為控制平面。
4. 若由 `ctrl-codex` 主導全局，容易讓 DB、通知、排程與工程驗收耦合在一起。

一句話原則：

`ctrl-hermes` 主導流程，`ctrl-codex` 主導工程判斷。

---

## 4. 誰連誰

建議採用以下單向主控連線模型：

```text
使用者 / Telegram / Web / CLI
  -> ctrl-hermes
      -> ssh / fixed command -> ctrl-codex
      -> ssh / fixed command -> worker-opencode
      -> ssh / fixed command -> worker-claude
      -> ssh / fixed command -> worker-antigravity
```

規則：

1. 使用者不直接碰 `ctrl-codex`。
2. `ctrl-hermes` 可以主動連 `ctrl-codex`。
3. `ctrl-hermes` 可以主動連 worker。
4. `ctrl-codex` 不應直接自由連 worker。
5. `ctrl-codex` 不應直接連 Hermes DB。
6. 任意遠端操作都必須透過固定腳本入口，不可即席拼接 SSH 命令。

---

## 5. 真實狀態來源

### 5.1 唯一真相

任務與 worker 狀態真相應保存在 `ctrl-hermes`：

1. `task_envelopes`
2. `task_executions`
3. `worker_state`

### 5.2 `ctrl-codex` 保存什麼

`ctrl-codex` 可保存本地工作副本與工程產物，但不應成為流程真相來源：

1. repository clone
2. 規劃中間檔
3. `execution-manifest.json`
4. `manifest-validation-result.json`
5. `acceptance.json`
6. `codex-review.json`
7. `codex-review.md`

### 5.3 不應共享的真相來源

以下都不應被當成真實狀態來源：

1. 對話紀錄
2. Hermes Memory
3. `ctrl-codex` 本機暫存檔
4. Worker 純文字回覆

---

## 6. 應共享的資訊

雙主機之間應共享的是 **task artifacts**，不是共用工作樹。

### 6.1 必須共享

至少應共享：

1. `task_id`
2. `task-envelope.json`
3. `execution-manifest.json`
4. `manifest-validation-result.json`
5. `worker-preflight-result.json`
6. `result.json`
7. `changed-files.txt`
8. `changes.patch`
9. `acceptance.json`
10. `codex-review.json`
11. `codex-review.md`
12. `commit_sha`
13. `base_ref`
14. `base_sha`
15. `approval_status`
16. `current_phase`
17. `status`

### 6.2 不應共享

以下資訊不應在主機間自由散布：

1. Hermes DB 寫入權限
2. SQLite DB 檔直接掛給 `ctrl-codex`
3. Worker OAuth token
4. 瀏覽器 profile
5. SSH 私鑰
6. 共用中的 worktree
7. 未遮蔽 secrets
8. 完整環境變數快照

---

## 7. 不共享的東西

雙主機架構中，以下做法應明確禁止：

1. 用 Syncthing 同步正在施工的 repository worktree。
2. 用共享網路磁碟同時讓兩台主機改同一份工作樹。
3. 讓 `ctrl-codex` 直接執行任意 SQL 更新 `coordination.db`。
4. 讓 worker 直接讀 Hermes DB 或直接改 task phase。
5. 讓 `ctrl-codex` 直接 SSH 到 worker 執行未受控命令。

---

## 8. 連線與驗證方式

### 8.1 網路

建議使用：

1. Tailscale 私網
2. 固定主機名
3. 私網 SSH

建議主機名：

1. `ctrl-hermes`
2. `ctrl-codex`
3. `worker-opencode`
4. `worker-claude`
5. `worker-antigravity`

### 8.2 身分驗證

建議：

1. 只允許 SSH 金鑰登入
2. 禁止密碼登入
3. 禁止 root 直接登入
4. 對每種目的使用固定受控帳號

### 8.3 推薦帳號

可用下列概念分工：

1. `hermesctl`：`ctrl-hermes` 上的控制平面帳號
2. `codexctl`：`ctrl-codex` 上的受控執行帳號
3. `agentworker`：各 worker 節點上的低權限帳號

若現場已經有固定帳號，也可以沿用，但必須滿足：

1. 可審計
2. 可限制目錄權限
3. 不具無限制 sudo

---

## 9. 目錄規劃

### 9.1 `ctrl-hermes`

建議根目錄：

```text
/srv/hermes-control/
├── bin/
├── config/
├── logs/
├── state/
├── tasks/
└── schemas/
```

用途：

1. `bin/`：固定入口腳本
2. `state/`：DB 與狀態檔
3. `tasks/`：task artifact 主目錄
4. `logs/`：控制平面執行日誌

### 9.2 `ctrl-codex`

建議根目錄：

```text
/srv/codex-supervisor/
├── repos/
├── worktrees/
├── tasks/
├── results/
├── logs/
└── bin/
```

用途：

1. `repos/`：repository clone
2. `worktrees/`：task 專屬工作樹
3. `tasks/`：輸入 task artifacts
4. `results/`：規劃與驗收產物
5. `bin/`：固定入口腳本

---

## 10. Task 共享目錄規則

### 10.1 `ctrl-hermes` 主目錄

每個 task 建議使用：

```text
/srv/hermes-control/tasks/TASK-ID/
```

### 10.2 `ctrl-codex` 工作目錄

每個 task 建議使用：

```text
/srv/codex-supervisor/results/TASK-ID/
```

### 10.3 固定檔名

兩邊都應保留一致檔名：

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

## 11. 正式入口腳本

雙主機之間不應互相暴露任意 shell 或任意 SQL。  
應只暴露固定用途腳本。

### 11.1 `ctrl-hermes` 應提供的正式入口

建議至少有：

1. `/srv/hermes-control/bin/task-create-envelope`
2. `/srv/hermes-control/bin/task-get-envelope`
3. `/srv/hermes-control/bin/task-store-manifest`
4. `/srv/hermes-control/bin/task-store-validation`
5. `/srv/hermes-control/bin/task-store-preflight`
6. `/srv/hermes-control/bin/task-store-result`
7. `/srv/hermes-control/bin/task-update-phase`
8. `/srv/hermes-control/bin/task-request-review`
9. `/srv/hermes-control/bin/dispatch-task`

### 11.2 `ctrl-codex` 應提供的正式入口

建議至少有：

1. `/srv/codex-supervisor/bin/plan-task`
2. `/srv/codex-supervisor/bin/review-task`
3. `/srv/codex-supervisor/bin/export-manifest`
4. `/srv/codex-supervisor/bin/export-review`

### 11.3 Worker 應提供的正式入口

建議至少有：

1. `/srv/agent/bin/run-opencode`
2. `/srv/agent/bin/run-claude`
3. `/srv/agent/bin/run-antigravity`
4. `/srv/agent/bin/run-codex`

---

## 12. 哪些腳本不應成為跨機主介面

以下類型腳本不應直接開放給跨機流程當主入口：

1. 任意 SQL 查詢器，例如 `db-query`
2. 任意 SQL 更新器，例如可自由更新 phase 的通用腳本
3. 可接受任意 shell 字串的 wrapper
4. 直接把 prompt 插入 SSH 命令列的腳本

原因：

1. 權限太寬
2. 邊界不清
3. 不利稽核
4. 容易破壞 `ctrl-hermes` / `ctrl-codex` / Dispatcher / Wrapper 的責任分工

若 `db-query` 類腳本存在，建議只作本機維運 / debug 用，不作正式雙機 API。

---

## 13. 雙主機工作流

### 13.1 Step 1：使用者請求進入 `ctrl-hermes`

`ctrl-hermes`：

1. 接收請求
2. 分配 `task_id`
3. 建立 `task-envelope.json`
4. 寫入 `task_envelopes`
5. 初始化 `task_executions`

### 13.2 Step 2：`ctrl-hermes` 呼叫 `ctrl-codex` 規劃

`ctrl-hermes` 透過固定 SSH 命令呼叫：

```text
ssh codexctl@ctrl-codex /srv/codex-supervisor/bin/plan-task TASK-ID
```

`plan-task` 內部應：

1. 取得 `task-envelope.json`
2. 讀取 repository
3. 產生 `execution-manifest.json`
4. 驗證 manifest
5. 產生 `manifest-validation-result.json`

### 13.3 Step 3：規劃產物回到 `ctrl-hermes`

回傳方式可用：

1. `scp` 回傳檔案
2. `rsync` 同步 task 目錄
3. `ctrl-codex` 呼叫 Hermes 固定 `store-*` 腳本

建議優先：

1. `ctrl-hermes` 建立 task 目錄
2. `ctrl-codex` 將規劃產物寫到自己的 `results/TASK-ID/`
3. `ctrl-hermes` 拉回所需檔案

### 13.4 Step 4：`ctrl-hermes` 更新狀態

當 manifest 驗證通過後：

1. `task_executions.current_phase = planned`
2. `task_executions.status = ready`
3. 保存 `execution_manifest_path`

### 13.5 Step 5：Dispatcher / Wrapper 做 preflight

由 `ctrl-hermes` 呼叫 Dispatcher：

```text
/srv/hermes-control/bin/dispatch-task TASK-ID
```

Dispatcher：

1. 讀取 `execution-manifest.json`
2. 讀取 `manifest-validation-result.json`
3. 根據 `dispatch_policy` 選擇 worker
4. 呼叫 wrapper 執行 runtime preflight
5. 取得 `worker-preflight-result.json`

### 13.6 Step 6：正式派工

只有在以下條件成立時才可正式派工：

1. `manifest-validation-result.json` 顯示 `dispatch_allowed = true`
2. `worker-preflight-result.json` 顯示 `preflight.available = true`

### 13.7 Step 7：Worker 回傳執行結果

Worker 至少回傳：

1. `result.json`
2. `worker.stdout`
3. `worker.stderr`
4. `changed-files.txt`
5. `changes.patch`
6. `commit_sha`

### 13.8 Step 8：`ctrl-hermes` 呼叫 `ctrl-codex` 驗收

`ctrl-hermes` 再透過固定 SSH 命令呼叫：

```text
ssh codexctl@ctrl-codex /srv/codex-supervisor/bin/review-task TASK-ID
```

`review-task` 應：

1. 讀取 manifest
2. 讀取 result 與 patch
3. 驗證 `allowed_paths`
4. 執行 acceptance commands
5. 產出 `acceptance.json`
6. 產出 `codex-review.json`
7. 產出 `codex-review.md`

### 13.9 Step 9：`ctrl-hermes` 最終收斂

`ctrl-hermes` 根據驗收結果：

1. 更新 `task_executions.current_phase`
2. 更新 `task_executions.status`
3. 通知使用者
4. 若需要人工核准，等待人工

---

## 14. 狀態更新責任

### 14.1 由 `ctrl-hermes` 更新

以下欄位應主要由 `ctrl-hermes` 更新：

1. `task_envelopes.*`
2. `task_executions.current_phase`
3. `task_executions.status`
4. `task_executions.dispatched_at`
5. `task_executions.started_at`
6. `task_executions.finished_at`
7. `task_executions.last_error`
8. `worker_state.*`

### 14.2 由 `ctrl-codex` 產出但不直接寫 DB

建議 `ctrl-codex` 產出檔案，再由 `ctrl-hermes` 消費並落庫：

1. `execution-manifest.json`
2. `manifest-validation-result.json`
3. `acceptance.json`
4. `codex-review.json`
5. `codex-review.md`

### 14.3 由 Worker / Wrapper 產出

1. `worker-preflight-result.json`
2. `result.json`
3. `worker.stdout`
4. `worker.stderr`

---

## 15. DB 與 artifacts 的關係

DB 應保存 **狀態摘要與路徑索引**，而不是取代 artifact 檔案本身。

建議：

1. DB 保存 `task_id`
2. DB 保存 phase / status
3. DB 保存 `execution_manifest_path`
4. DB 保存 `result_path`
5. DB 保存 `worker_id`
6. DB 保存 `branch`
7. DB 保存 `worktree_path`

Artifact 檔案保存完整內容：

1. manifest 本文
2. validation result 本文
3. preflight result 本文
4. result 本文
5. review 本文

---

## 16. 安全邊界

### 16.1 `ctrl-hermes`

1. 不接受任意 SQL。
2. 不接受任意 shell 字串。
3. 不把 DB 目錄直接分享給 `ctrl-codex`。
4. 只允許固定腳本入口。

### 16.2 `ctrl-codex`

1. 不直接取得 Hermes DB 寫入權限。
2. 不直接自由 SSH 到 worker。
3. 不以對話內容取代 artifact 落地。
4. 不可繞過 Dispatcher 直接派工。

### 16.3 Worker

1. 不可直接改 Hermes phase。
2. 不可自行決定 accepted。
3. 不可自行擴張 `allowed_paths`。
4. 不可讀控制平面 secrets。

---

## 17. 最小可行版本

若要先做 MVP，建議只上三個節點：

1. `ctrl-hermes`
2. `ctrl-codex`
3. `worker-opencode`

MVP 先完成：

1. `task envelope`
2. `execution manifest`
3. manifest validation
4. wrapper preflight
5. worker execution
6. codex review
7. DB phase 更新

等 OpenCode 跑穩後，再接：

1. `worker-claude`
2. `worker-antigravity`

---

## 18. 施工順序

建議按以下順序落地：

1. 完成雙主機 Tailscale 與 SSH 金鑰登入
2. 完成 `ctrl-hermes` DB 與 task 目錄
3. 完成 `ctrl-codex` repo / worktree / results 目錄
4. 完成 `task-create-envelope`
5. 完成 `plan-task`
6. 完成 `manifest-validation-result` 落地
7. 完成 `dispatch-task`
8. 完成 `run-opencode` wrapper
9. 完成 `review-task`
10. 完成 task artifact 雙邊同步
11. 跑一個單一 task 端到端測試
12. 補上通知、阻塞、fallback

---

## 19. 驗收清單

雙主機藍圖落地後，至少要驗證：

1. `ctrl-hermes` 能 SSH 到 `ctrl-codex`
2. `ctrl-hermes` 能 SSH 到 worker
3. `ctrl-codex` 不需要 DB 直接存取權也能完成規劃與驗收
4. `execution-manifest.json` 能落地回傳到 `ctrl-hermes`
5. `manifest-validation-result.json` 能阻止不合格派工
6. `worker-preflight-result.json` 能阻止 quota / auth 不可用 worker 開工
7. `result.json`、patch、review 會被保存到 task 目錄
8. phase / status 更新只由 `ctrl-hermes` 收斂
9. task 完成後能在 `ctrl-hermes` 查到完整追溯資料

---

## 20. 一句話定案

```text
ctrl-hermes 管流程與狀態
ctrl-codex 管規劃與驗收
worker 管受控執行
共享的是 task artifacts
不共享的是 DB 寫權、worktree 與 secrets
```

