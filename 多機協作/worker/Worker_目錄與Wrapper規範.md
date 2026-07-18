# Worker 目錄與 Wrapper 規範

本文件定義 worker 節點上的目錄結構、Wrapper 角色、結果檔案與 exit code 協定。

適用對象：

1. `worker-opencode`
2. `worker-claude`
3. `worker-antigravity`
4. `worker-codex`

所有文字檔、JSON 檔、Markdown 檔與設定檔，預設編碼一律使用 `UTF-8`。

---

## 1. 目錄根路徑

worker 節點建議使用以下根目錄：

```text
/srv/agent/
├── repos/
├── worktrees/
├── logs/
├── tasks/
├── results/
└── bin/
```

用途：

1. `repos/`：保存專案主 clone
2. `worktrees/`：保存每個 task 的隔離工作樹
3. `logs/`：保存 task 執行日誌
4. `tasks/`：保存 manifest、validation result、prompt 或其他受控輸入
5. `results/`：保存結構化結果
6. `bin/`：保存 worker wrapper 腳本

---

## 2. 建議目錄命名

以 `TASK-20260718-001` 為例：

```text
/srv/agent/repos/YOUR_REPO
/srv/agent/worktrees/TASK-20260718-001
/srv/agent/logs/TASK-20260718-001
/srv/agent/tasks/TASK-20260718-001.execution-manifest.json
/srv/agent/tasks/TASK-20260718-001.manifest-validation-result.json
/srv/agent/results/TASK-20260718-001.result.json
```

---

## 3. Wrapper 的角色

Wrapper 是 worker 的標準化邊界，負責：

1. 接收 manifest
2. 接收對應的 validation result
3. 執行 worker 可用性預檢
4. 檢查 worker 狀態
5. 檢查 quota / cooldown / auth
6. 驗證 `dispatch_allowed = true`
7. 執行真正的 CLI
8. 收集 stdout / stderr
9. 產出統一結果 JSON
10. 標準化 exit code

原則：

1. Hermes 與 Codex 不直接依賴 CLI 畫面文字
2. 由 Wrapper 將 CLI 輸出轉為標準結構
3. 預檢規則由 `ctrl-codex` 制定，Wrapper 不可自行改寫准派或改派邏輯
4. Hermes / Dispatcher 依 Wrapper 產出的預檢結果執行派工流程

---

## 4. 建議 Wrapper 位置

建議：

```text
/srv/agent/bin/run-opencode
/srv/agent/bin/run-claude
/srv/agent/bin/run-antigravity
/srv/agent/bin/run-codex
```

每個 wrapper 應：

1. 只處理單一類型 worker
2. 輸出一致格式
3. 保留原始錯誤輸出位置
4. 不得忽略 manifest 中的 `development_process`、`commit_rules`
5. 若對應 `worker-codex`，仍僅為執行 wrapper，不等同於 `ctrl-codex`
6. 對 `worker-claude`、`worker-antigravity`、`worker-codex` 必須先做限額 / auth 預檢

---

## 5. 預檢結果檔案

每個 task 在真正啟動 worker 前，建議先產出一份預檢結果：

```text
/srv/agent/results/TASK-ID.preflight.json
```

建議內容至少包含：

1. `agent`
2. `checked_at`
3. `available`
4. `reason.category`
5. `retry_after`
6. `raw_message_file`
7. `fallback_recommended`

預檢用途：

1. 讓 Dispatcher 在派工前就知道該 worker 是否可接單
2. 避免已知限額狀態下仍進入 worktree 施工
3. 讓 Hermes / `ctrl-codex` 可追蹤 worker 可用性變化

---

## 6. 標準結果檔案

每個 task 至少應保存：

```text
/srv/agent/logs/TASK-ID/
├── worker.stdout
├── worker.stderr
└── wrapper.stderr

/srv/agent/tasks/
├── TASK-ID.execution-manifest.json
└── TASK-ID.manifest-validation-result.json

/srv/agent/results/
├── TASK-ID.preflight.json
└── TASK-ID.result.json
```

若由上層集中收斂，也可另外複製到 Codex / Hermes 的 task 目錄。

---

## 7. `result.json` 最小結構

建議格式：

```json
{
  "task_id": "TASK-20260718-001",
  "agent": "opencode",
  "worker_id": "opencode-01",
  "status": "completed",
  "preflight": {
    "checked": true,
    "available": true,
    "category": null,
    "retry_after": null
  },
  "validation": {
    "dispatch_allowed": true
  },
  "development_process": {
    "tdd_required": true,
    "verification_strategy": "unit-and-integration-tests"
  },
  "reason": null,
  "execution": {
    "started": true,
    "exit_code": 0,
    "duration_seconds": 120
  },
  "commit_sha": "0123456789abcdef",
  "logs": {
    "stdout": "logs/TASK-ID/worker.stdout",
    "stderr": "logs/TASK-ID/worker.stderr"
  },
  "fallback_recommended": false
}
```

若失敗，應補 `reason.category`、`retry_after`、`raw_message_file`。
若與流程規則衝突，應額外補 `process_mismatch_reason`。
若在預檢階段就被擋下，應明確反映在 `preflight` 區塊。

---

## 8. Exit Code 協定

以下 exit code 為系統協定，Wrapper 必須遵守：

| Code | 意義 |
|---:|---|
| 0 | 任務完成 |
| 70 | Agent 執行錯誤 |
| 71 | 登入失效 |
| 72 | 權限確認或互動阻塞 |
| 73 | 5 小時額度限制（Antigravity） |
| 74 | 7 天 / weekly 限制（Antigravity） |
| 75 | 額度限制但窗口未知 |
| 76 | 網路錯誤 |
| 77 | 任務逾時 |
| 78 | 修改範圍越界 |
| 79 | 驗收失敗 |
| 80 | Codex CLI 短期速率限制 |
| 81 | Codex CLI 帳號配額或日用量上限 |
| 82 | Codex CLI 帳號登入失效 |
| 83 | Claude Code 短期速率限制 |
| 84 | Claude Code 每日 / 月用量上限 |
| 85 | Claude Code 帳號登入失效 |

---

## 9. Worker 預檢規則

預檢不是可選項，而是派工前的必要步驟。

規則如下：

1. `worker-opencode`：做基本健康檢查即可
2. `worker-claude`：必須檢查短期速率限制、每日 / 月額度、登入狀態
3. `worker-antigravity`：必須檢查 5 小時限制、7 天 / weekly 限制、登入狀態
4. `worker-codex`：必須檢查短期速率限制、帳號配額、登入狀態
5. 若預檢判定不可用，不得執行真正的 worker CLI
6. 若預檢失敗但可估算恢復時間，必須回填 `retry_after`

補充：

1. 預檢項目與分類標準由 `ctrl-codex` 維護，不由各 worker 自行決定
2. Wrapper 只負責執行檢查與輸出結果，不負責決定是否永久改派
3. Dispatcher / Hermes 依 `ctrl-codex` 規則消費 `TASK-ID.preflight.json`

---

## 10. Cooldown 與 Fallback 標準化

Wrapper 必須標準化以下情況：

1. quota 用盡
2. auth 失效
3. timeout
4. network error

應輸出：

1. `status`
2. `reason.category`
3. `reason.window`
4. `reason.retry_after`
5. `fallback_recommended`
6. 若阻塞原因與 manifest 規定流程衝突有關，補 `process_mismatch_reason`
7. 若阻塞發生於派工前預檢，補 `preflight.category`

---

## 11. Worktree 管理規則

每個 task 都必須對應一個獨立 worktree。

原則：

1. 不共用 worktree
2. 不在主 clone 直接施工
3. task 結束前不可刪除必要證據
4. worktree 名稱優先使用 `task_id`

---

## 12. 一句話原則

`Wrapper 負責把不穩定的 CLI 行為，轉成穩定的系統協定。`
