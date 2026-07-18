# Worker 差異化定位

本文件定義四種 worker 的差異化定位。

適用對象：

1. `worker-opencode`
2. `worker-claude`
3. `worker-antigravity`
4. `worker-codex`

原則：

1. 四種 worker 在制度上平等
2. 四種 worker 在安全邊界上一致
3. 四種 worker 在調度上分工，不視為完全等價資源
4. 四種 worker 都必須遵守既定 `tech_decisions`、`development_process` 與 `commit_rules`

所有文字檔、JSON 檔、Markdown 檔與設定檔，預設編碼一律使用 `UTF-8`。

---

## 1. 共同底線

無論是哪一種 worker，都必須遵守共同底線：

1. 只能接收 `execution manifest`
2. 只能在指定 `branch/worktree` 內工作
3. 只能修改 `allowed_paths`
4. 必須輸出結構化結果
5. 必須服從 validation result 與派工前驗證結論
6. 不能直接當最終驗收者

---

## 2. OpenCode 的定位

### 適合接的模組類型

1. 明確、邊界清楚的程式任務
2. 結構化輸出要求高的模組
3. 小到中型程式修改
4. 規則明確的 wrapper / schema / JSON / config 工作
5. 需要穩定重複執行的自動化任務
6. 預設要求 `TDD` 且可切成小模組的工作

### 典型例子

1. API client 封裝
2. schema 檔建立
3. 小型 service / repository 修改
4. 測試補齊
5. 標準化 JSON 輸出工作
6. migration 驗證或 smoke test 腳本

### 不優先的情況

1. 大型跨檔案重構
2. 高度依賴抽象推理的架構調整
3. 需要長鏈推導與大量上下文理解的工作
4. 大規模跨模組重構且必須維持長鏈設計一致性

---

## 3. Claude 的定位

### 適合接的模組類型

1. 大型跨檔案理解任務
2. 結構調整與重構
3. 較高推理密度的程式設計工作
4. 前後端邏輯關聯較強的模組
5. 需要整體性理解的模組拆解與修補
6. 需要在 `SOLID` / `Clean Code` 條件下進行結構整理的工作

### 典型例子

1. App Router 結構整理
2. 跨層 service / route / repository 重構
3. 複雜 UI 狀態與資料流整合
4. 跨多檔案型別一致性修正
5. 先有測試、再做重構的中大型模組整理

### 不優先的情況

1. 非常小而機械化的修補
2. 純結構化輸出導向、規則高度固定的任務
3. 額度已接近上限時的高頻小任務
4. 單純機械化的文件搬運或固定格式輸出

### 派工前檢查要求

1. `worker-claude` 派工前必做限額與登入狀態預檢
2. 若短期速率限制或每日 / 月額度不足，應優先改派，不應先進入 worktree

---

## 4. Antigravity 的定位

### 適合接的模組類型

1. 可由其能力優勢完成的特定執行工作
2. 有明確輸入輸出且可隔離的模組
3. 作為特定任務的補充執行資源
4. 已經明確定義 `verification_strategy` 且可快速判定成功與失敗的獨立單元

### 典型例子

1. 已被 manifest 明確界定的獨立模組
2. 需要補位的 fallback 工作
3. 可清楚量化成功與失敗的任務
4. 不需要長鏈 TDD 循環的獨立模組

### 特別限制

1. quota / cooldown 風險較高
2. 登入與額度狀態必須特別治理
3. 調度時不可忽略其 5 小時 / weekly 類型限制
4. 不適合承擔高度依賴連續互動與長時間重構的模組

### 派工前檢查要求

1. `worker-antigravity` 派工前必做 5 小時與 7 天 / weekly 類型限額預檢
2. 只要預檢顯示窗口內不可用，就應直接阻止派工並進入 fallback 判斷

### 不優先的情況

1. 長鏈多模組工作
2. 高度依賴穩定長時執行的任務
3. 在 quota 不明或接近上限時的大量派工

---

## 5. Codex 的定位

### 適合接的模組類型

1. 需要嚴格遵守 manifest 規則的程式模組
2. 需要明確保留驗證證據、commit 邊界與結果結構的任務
3. 中到大型、但責任邊界已切清楚的跨檔案修改
4. 對 `TDD`、`SOLID`、`Clean Code` 要求較高的實作工作
5. 需要與 `execution manifest` 欄位強對齊的 worker 執行任務

### 典型例子

1. 已明確切模組的 service / repository / route 協同修改
2. 需要同時保留測試、驗證輸出與 commit 邊界的修補任務
3. manifest 規格、wrapper 規格、驗收規格配套實作
4. 已完成技術選型後的中大型獨立模組開發

### 特別說明

1. `worker-codex` 是執行層 worker，不等同於 `ctrl-codex`
2. `worker-codex` 不負責補做技術選型、不負責產生 manifest，也不負責最終驗收
3. 若任務仍處於需求未定案或架構未收斂階段，應先回到上層規劃，而不是直接派給 `worker-codex`

### 派工前檢查要求

1. `worker-codex` 派工前必做速率限制、帳號配額與登入狀態預檢
2. 若預檢失敗，應回報 `quota_exhausted` 或 `auth_invalid`，不得直接開工

### 不優先的情況

1. 技術選型尚未定案的任務
2. 需求邊界模糊、仍需大量來回澄清的任務
3. 僅需簡單機械化輸出的超小型任務

---

## 6. 調度原則

建議調度順序不是固定單一路徑，而是依模組性質選擇：

1. 邊界清楚、規則明確、結構化輸出任務：優先 `OpenCode`
2. 大範圍理解、跨檔案重構、高推理密度任務：優先 `Claude`
3. 特定補位、獨立模組、需另用資源池的任務：視情況使用 `Antigravity`
4. 對 manifest 遵循、驗證證據、commit 邊界要求特別強的獨立模組：可優先 `Codex`
5. 若 manifest 對 `TDD`、重構分離、技術選型依賴特別強，應優先選能穩定遵守該流程的 worker

---

## 7. Fallback 原則

fallback 不代表三者完全等價，而是表示：

1. 在原 worker 因 quota / auth / timeout 無法繼續時，是否有可接替資源
2. 接替者是否能承擔該模組的責任邊界

建議：

1. `OpenCode -> Claude`：適合小中型任務升級到較強推理
2. `Claude -> OpenCode`：適合將較明確的模組重新切小後改派
3. `Antigravity -> Claude / OpenCode`：當其 quota 或 auth 出問題時回切
4. `OpenCode / Claude -> Codex`：適合 manifest 已很完整，但需要更嚴格流程落地時切換
5. `Codex -> Claude / OpenCode`：適合將已切清楚的子模組改派到其他可執行資源

---

## 8. 一句話原則

`worker 在制度上平等，在調度上分工。`
