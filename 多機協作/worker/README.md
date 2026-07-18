# Worker 文件索引

本目錄收錄 Hermes + Codex 多機協作架構中，所有 `worker` 相關的共同規範文件。

適用對象：

1. `worker-opencode`
2. `worker-claude`
3. `worker-antigravity`
4. `worker-codex`
5. 負責 Dispatcher / Wrapper / 派工驗證的人員或 agent
6. 負責 worker 驗收、稽核、安全檢查的人員或 agent

所有文字檔、JSON 檔、Markdown 檔與設定檔，預設編碼一律使用 `UTF-8`。

---

## 文件總覽

### 1. `Worker_責任邊界.md`

用途：

- 定義 worker 的共同角色定位
- 說明 worker 應負責與不應負責的事項
- 界定 worker 與 Hermes / Codex / Dispatcher 的責任邊界

適合閱讀時機：

- 設計 worker 制度
- 檢查 worker 是否越權
- 定義 worker 不該做什麼
- 釐清 `ctrl-codex`、`wrapper`、`Hermes / Dispatcher` 的預檢分工

### 2. `Worker_標準工作流程.md`

用途：

- 定義 worker 從接收 manifest 到輸出 JSON 的標準流程
- 說明失敗分類、cooldown、fallback 與流程規則
- 加入 `Claude / Antigravity / Codex` 的派工前限額預檢機制
- 納入 `TDD`、`verification_strategy`、`commit_rules` 的執行要求

適合閱讀時機：

- 設計 worker 執行流程
- 撰寫 wrapper 或自動化腳本
- 檢查 worker 是否依正確順序工作
- 定義誰負責預檢規則、誰負責預檢執行、誰負責改派

### 3. `Worker_差異化定位.md`

用途：

- 定義 `OpenCode / Claude / Antigravity / Codex` 的差異化定位
- 說明哪類模組適合派給哪一種 worker
- 說明 fallback 與調度考量

適合閱讀時機：

- 規劃 manifest 的 `preferred_agent`
- 決定 fallback agent
- 檢查某個模組是否派錯 worker

### 4. `Worker_目錄與Wrapper規範.md`

用途：

- 定義 `/srv/agent/...` 的目錄規範
- 定義 wrapper 的角色、結果檔案與 exit code 協定
- 定義 `TASK-ID.preflight.json` 與派工前可用性檢查
- 說明 `result.json`、`manifest-validation-result`、stdout/stderr 保存方式
- 明確區分 `ctrl-codex` 的規則制定責任與 wrapper 的執行責任

適合閱讀時機：

- 建立 worker 節點
- 撰寫 wrapper 腳本
- 定義結果檔案與日誌保存位置

### 5. `Worker_安全限制.md`

用途：

- 定義 SSH、帳號、檔案系統、秘密存取、網路與安裝限制
- 說明 prompt injection 防護與越界修改處理
- 補強 manifest 規則不可被 worker 放寬的安全底線

適合閱讀時機：

- 建立 worker 安全政策
- 檢查 worker 是否有越權風險
- 做安全審查或事故排查

---

## 建議閱讀順序

若是第一次建立 worker 制度，建議順序如下：

1. `Worker_責任邊界.md`
2. `Worker_標準工作流程.md`
3. `Worker_差異化定位.md`
4. `Worker_目錄與Wrapper規範.md`
5. `Worker_安全限制.md`

原因：

1. 先定義 worker 是什麼、不是什麼
2. 再定義 worker 怎麼工作
3. 再區分四種 worker 的角色差異
4. 再落地到目錄、wrapper、結果檔案
5. 最後補上安全限制與越權防護

---

## 與其他目錄的關係

本目錄應與以下文件搭配閱讀：

### Codex 規則與 Manifest 規格

- `../codex/REPO_root/AGENTS.md`
- `../codex/REPO_root/AgentsRule/execution-manifest-spec.md`
- `../codex/REPO_root/AgentsRule/execution-manifest.schema.json`
- `../codex/REPO_root/AgentsRule/execution-manifest-驗證流程說明.md`

用途：

- 說明 worker 應執行什麼
- 說明 manifest 內有哪些規則不能被 worker 改寫
- 說明 validation result 與 `dispatch_allowed` 的來源

### 整體多機協作總設計

- `../Hermes_Codex_多機Agent協作最終佈建報告.md`

用途：

- 說明 worker 在整體系統中的位置
- 說明它與 Hermes / Codex / Dispatcher 的互動方式

---

## 一句話總結

`worker` 目錄下的文件，負責定義執行層如何在不越權的前提下，穩定執行 manifest、輸出結果、接受驗收，並與整個多機協作系統對齊。
