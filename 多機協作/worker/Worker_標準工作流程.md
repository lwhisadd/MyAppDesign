# Worker 標準工作流程

本文件定義所有 worker 的共同標準工作流程。

適用對象：

1. `worker-opencode`
2. `worker-claude`
3. `worker-antigravity`
4. `worker-codex`

所有文字檔、JSON 檔、Markdown 檔與設定檔，預設編碼一律使用 `UTF-8`。

---

## 1. 流程目標

worker 的標準工作流程必須同時滿足以下目標：

1. 任務邊界清楚
2. 執行結果可追溯
3. 失敗可分類
4. quota / cooldown 可治理
5. fallback 有明確觸發條件

---

## 2. 標準流程總覽

所有 worker 都應遵守以下流程：

1. 接收 `execution manifest`
2. 讀取並確認對應的 manifest validation result
3. 先做 worker 可用性預檢
4. 驗證 manifest 與執行環境
5. 進入指定 `worktree`
6. 在 `allowed_paths` 內執行任務
7. 保存 stdout / stderr / 結果 JSON
8. 若成功，提交 commit
9. 若失敗，輸出標準化錯誤分類
10. 若遇 quota / auth / timeout，回寫對應狀態
11. 將結果交回 Dispatcher / Codex

---

## 3. Step 1：接收 Manifest

worker 必須接收已定案的 `execution manifest`，不得依口頭描述或未落地的對話內容直接施工。

最少應確認：

1. `task_id`
2. `project`
3. `base_ref`
4. `allowed_paths`
5. `acceptance_commands`
6. `tech_decisions`
7. `development_process`
8. `commit_rules`
9. 目標模組或任務描述
10. `timeout_seconds`

若缺少關鍵欄位，應立即停止並回報 `blocked`。

---

## 4. Step 2：Worker 可用性預檢

正式進入 worktree 前，Wrapper 必須先確認目標 worker 目前是否可接單。

角色分工：

1. `ctrl-codex`：定義哪些 worker 必須預檢、預檢欄位、失敗分類、准派與改派規則
2. `wrapper`：實際執行當下的 quota / auth / cooldown / rate limit 檢查
3. Hermes / Dispatcher：根據預檢結果決定是否派工、改派、進入 cooldown 或等待人工處理
4. `worker` 本體：只接收預檢後允許執行的 task，不負責自己制定預檢規則

預檢原則：

1. `worker-opencode`：做一般健康檢查即可，不以 quota 為主要阻塞來源
2. `worker-claude`：必須檢查登入狀態、短期速率限制、每日或月度額度
3. `worker-antigravity`：必須檢查登入狀態、5 小時窗口限制、7 天或 weekly 類型限制
4. `worker-codex`：必須檢查登入狀態、短期速率限制、帳號配額或日用量上限

若預檢失敗：

1. 不得進入 worktree 執行實作
2. 必須直接輸出結構化阻塞結果
3. 必須帶出 `reason.category`、`retry_after` 與 `fallback_recommended`
4. 由 Dispatcher / Hermes 依 `ctrl-codex` 既定規則決定是否改派

---

## 5. Step 3：驗證執行前提

進入 worktree 前，至少檢查：

1. 目標 worktree 是否存在
2. branch 是否與 `task_id` 對應
3. manifest validation result 是否存在且 `dispatch_allowed = true`
4. Step 2 的 worker 可用性預檢是否已通過
5. quota / cooldown 是否允許執行
6. 必要工具是否存在
7. manifest 是否超出 worker 的責任邊界

若任一檢查失敗，應輸出結構化阻塞結果，不可硬做。

---

## 6. Step 4：進入 Worktree

worker 必須只在指定 worktree 中工作。

原則：

1. 不可直接在 repository 主 clone 上改動
2. 不可使用其他 task 的 worktree
3. 不可在 worktree 外產生未受控變更

---

## 7. Step 5：執行任務

worker 執行任務時應遵守：

1. 只能修改 `allowed_paths`
2. 不可擴張需求範圍
3. 不可自行改變技術選型
4. 不可跳過 manifest 中要求的模組邊界
5. 不可把不相關變更混入同一任務
6. 若 manifest 要求 `TDD`，應先寫失敗測試，再做最小實作，最後才重構
7. 若 manifest 要求將重構與行為變更分離，不可混在同一次 commit
8. 若 manifest 明確列出 `tech_decisions`，不可私自替換語言、框架、資料存取方式或狀態管理策略
9. 若 `tdd_required = false`，必須遵守 manifest 中定義的替代驗證方式

若任務過程中發現 manifest 與實際需求不一致，應停止並回報，不可自行重寫任務。

---

## 8. Step 6：保存執行輸出

執行過程中，worker 至少應保存：

1. `worker.stdout`
2. `worker.stderr`
3. `result.json`
4. 若有需要，保存測試輸出或替代驗證輸出
5. 必要時的中間錯誤訊息

結果不可只存在終端輸出中。

---

## 9. Step 7：成功時的處理

若任務成功完成，worker 應：

1. 確認變更仍在 `allowed_paths`
2. 執行必要的本地驗證，並符合 manifest 的 `verification_strategy`
3. 若 manifest 要求分離重構與行為變更，確認 commit 邊界符合規定
4. 提交 commit
5. 輸出 `completed` 狀態
6. 回報 commit SHA

worker 的成功不代表任務最終 accepted，仍需經過 Codex 驗收。

---

## 10. Step 8：失敗分類

worker 失敗時，不可只回傳「失敗」。

至少應分類為以下其中一類：

1. `failed`
2. `blocked`
3. `quota_exhausted`
4. `auth_invalid`
5. `timeout`
6. `scope_violation`
7. `environment_missing`
8. `network_error`
9. `validation_failed`
10. `process_mismatch`

每一類都應附帶：

1. 錯誤摘要
2. 原始輸出位置
3. 是否建議 fallback
4. 若與 `development_process` 或 `commit_rules` 衝突，應標示衝突點
5. 若屬限額或登入阻塞，應標示是哪一種預檢失敗

---

## 11. Step 9：Cooldown / Fallback

當 worker 遇到以下情況時，應觸發 cooldown 或 fallback 判斷：

1. quota 用盡
2. 帳號登入失效
3. 短期速率限制
4. 長期額度限制
5. 環境暫時不可用

處理原則：

1. `quota_exhausted`
   - 寫入 `retry_after`
   - 不得自行立即重試
   - 建議 fallback
2. `auth_invalid`
   - 停止派工
   - 交由人工重新登入
   - 不自動重試
3. `timeout`
   - 保留已知輸出
   - 由外層判斷是否重派
4. `failed`
   - 若屬實作失敗，不自動切 fallback，應先由 Codex 判斷

補充：

1. `worker-claude`、`worker-antigravity`、`worker-codex` 一律先做限額預檢，再決定是否進入 cooldown / fallback 判斷
2. 不可把已知的限額阻塞偽裝成一般 `failed`

---

## 12. Step 10：回傳 JSON

worker 最終必須回傳結構化結果 JSON。

最少應包含：

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
  "development_process": {
    "tdd_required": true,
    "verification_strategy": "unit-and-integration-tests"
  },
  "execution": {
    "exit_code": 0,
    "duration_seconds": 120
  },
  "commit_sha": "0123456789abcdef",
  "result_file": "logs/TASK-ID/result.json",
  "fallback_recommended": false
}
```

若失敗，應補充：

1. `reason.category`
2. `reason.retry_after`
3. `raw_message_file`
4. `process_mismatch_reason`
5. `preflight.category`

---

## 13. 與外層系統的邊界

worker 完成後，責任交接如下：

1. Worker：回傳執行事實
2. Wrapper：執行預檢並標準化錯誤與結果
3. Dispatcher：依預檢與結果執行派工、改派、cooldown、重試
4. Codex：定義預檢規則、判讀預檢結果、做最終驗收
5. Hermes：做排程、通知、阻塞與恢復管理

補充：

1. `worker-codex` 屬於執行層，仍需遵守相同流程，不因名稱為 Codex 而取得額外規劃或驗收權限

worker 不直接決定：

1. 是否 accepted
2. 是否 merge
3. 是否 deploy
4. 是否永久切換 fallback agent
