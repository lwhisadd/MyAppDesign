# Execution Manifest 驗證流程說明

本文件定義 `execution manifest` 在派工前應如何驗證，讓 `ctrl-codex`、Dispatcher、Wrapper、人工審查都能用一致流程檢查品質。

所有文字檔、JSON 檔與範例內容，預設編碼一律使用 `UTF-8`。

---

## 1. 驗證目標

`execution manifest` 的驗證目標有四個：

1. 結構正確
2. 模組拆分合理
3. 依賴關係可追溯且無循環
4. 可安全派工且可獨立驗收
5. 明確區分 manifest 驗證與 runtime preflight 的責任

---

## 2. 驗證責任分工

### Codex

Codex 在產生 manifest 時必須完成：

1. schema 結構檢查
2. 模組單一職責檢查
3. 模組獨立驗收性檢查
4. 依賴圖一致性檢查
5. 路徑範圍與副作用檢查
6. 定義 `dispatch_policy` 與 preflight 必查項目

### Wrapper

Wrapper 在正式派工前必須完成：

1. 根據 `dispatch_policy` 執行 runtime preflight
2. 檢查 health / auth / quota / cooldown / rate limit
3. 輸出標準化 preflight 結果
4. 不自行改寫 `ctrl-codex` 制定的准派或改派規則

### Dispatcher

Dispatcher 在派工前至少要完成：

1. schema 是否通過
2. task_id 是否存在
3. `allowed_paths` / `denied_paths` 是否合理
4. 模組是否存在空清單或缺關鍵欄位
5. `dispatch_policy` 是否完整
6. 若有外部驗證結果，是否標記為可派工
7. 若需要 runtime preflight，是否已取得 Wrapper 預檢結果

### 人工審查者

人工主要檢查：

1. 是否有不合理的大模組
2. 是否把不相關變更硬塞成單一模組
3. 是否有明顯的 DB / workflow / deployment 風險

---

## 3. 驗證階段

建議分成六個階段：

1. 編碼與檔案讀取檢查
2. JSON Schema 結構檢查
3. 模組語意檢查
4. 依賴圖檢查
5. 派工可行性檢查
6. runtime preflight 交接檢查

---

## 4. 階段一：編碼與檔案讀取檢查

規則：

1. 預設以 `UTF-8` 讀取 manifest
2. 若讀取失敗，不可直接用系統預設編碼覆蓋嘗試
3. 若懷疑非 UTF-8，必須先記錄阻塞原因

驗證通過標準：

1. 檔案可用 UTF-8 正常讀取
2. JSON 不含亂碼或截斷

---

## 5. 階段二：JSON Schema 結構檢查

必查項目：

1. 是否符合 `execution-manifest.schema.json`
2. `required` 欄位是否齊全
3. `task_id` 格式是否正確
4. `modules` 是否至少有一個元素
5. `preferred_agent`、`fallback_agents` 是否在允許值內

驗證結果分類：

- `pass`
- `fail_schema`

若 `fail_schema`，禁止派工。

---

## 6. 階段三：模組語意檢查

必查項目：

1. 每個模組是否只有單一責任
2. 模組是否可獨立驗收
3. 是否有不相關變更被合併
4. `inputs` 是否列出型別與來源
5. `outputs` 是否列出產出與回傳
6. `side_effects` 是否正確聲明
7. `allowed_paths` 是否與模組責任一致
8. `acceptance_commands` 是否足以驗證該模組

驗證結果分類：

- `pass`
- `fail_module_design`

若 `fail_module_design`，禁止派工。

---

## 7. 階段四：依賴圖檢查

必查項目：

1. 所有依賴是否都指向存在的 `module_id`
2. `upstream_dependencies` 與 `downstream_dependencies` 是否互相對應
3. 是否存在孤立模組
4. 是否存在循環依賴
5. 是否存在職責重疊造成的假依賴

建議做法：

1. 先把模組關係轉成圖
2. 檢查圖是否可拓樸排序
3. 若不可拓樸排序，優先懷疑循環依賴

驗證結果分類：

- `pass`
- `fail_dependency_graph`

若 `fail_dependency_graph`，禁止派工。

---

## 8. 階段五：派工可行性檢查

必查項目：

1. `allowed_paths` 是否超出任務範圍
2. `denied_paths` 是否與實際需求衝突
3. `timeout_seconds` 是否合理
4. `preferred_agent` 是否適合該模組
5. `fallback_agents` 是否存在
6. 是否涉及人工核准項目
7. acceptance commands 是否可在目標環境執行
8. `dispatch_policy` 是否明確指定 `ctrl-codex`、Wrapper、Dispatcher 的責任分工

驗證結果分類：

- `pass`
- `fail_dispatch_readiness`

若 `fail_dispatch_readiness`，應回到 Codex 修 manifest 或調整任務策略。

---

## 9. 階段六：runtime preflight 交接檢查

manifest 驗證通過，不等於可以直接開始正式執行。

必查項目：

1. 若 `dispatch_policy.preflight_required = true`，是否已明確要求 Wrapper 執行 preflight
2. validation result 是否明確標示下一步為 `run_wrapper_preflight`
3. Dispatcher 是否只在收到 preflight pass 後才進入正式派工
4. 是否避免把 Wrapper 預檢責任錯誤下放給 Worker 本體

驗證結果分類：

- `pass`
- `fail_preflight_handoff`

若 `fail_preflight_handoff`，禁止正式派工。

---

## 10. 驗證結果建議格式

建議輸出一份機器可讀摘要：

```json
{
  "task_id": "TASK-20260718-001",
  "manifest_validation": {
    "encoding": "pass",
    "schema": "pass",
    "module_design": "pass",
    "dependency_graph": "pass",
    "dispatch_readiness": "pass"
  },
  "dispatch_gate": {
    "manifest_dispatch_eligible": true,
    "runtime_preflight_required": true,
    "preflight_rule_owner": "ctrl-codex",
    "preflight_execution_owner": "wrapper",
    "dispatch_execution_owner": "dispatcher",
    "runtime_preflight_status": "pending"
  },
  "warnings": [],
  "errors": [],
  "dispatch_allowed": true,
  "next_action": {
    "action": "run_wrapper_preflight",
    "reason": "manifest validation passed and runtime preflight is required before dispatch"
  }
}
```

若失敗，應能定位問題：

```json
{
  "task_id": "TASK-20260718-001",
  "manifest_validation": {
    "encoding": "pass",
    "schema": "pass",
    "module_design": "fail",
    "dependency_graph": "not_run",
    "dispatch_readiness": "not_run"
  },
  "dispatch_gate": {
    "manifest_dispatch_eligible": false,
    "runtime_preflight_required": true,
    "preflight_rule_owner": "ctrl-codex",
    "preflight_execution_owner": "wrapper",
    "dispatch_execution_owner": "dispatcher",
    "runtime_preflight_status": "not_run"
  },
  "warnings": [],
  "errors": [
    {
      "module_id": "orders.all-in-one",
      "category": "single_responsibility_violation",
      "message": "模組同時包含 API、migration 與前端文案修改"
    }
  ],
  "dispatch_allowed": false
}
```

---

## 11. 阻塞處理原則

若驗證失敗，處理方式如下：

1. `fail_schema`
   - 直接退回修正
   - 不進入依賴檢查

2. `fail_module_design`
   - 退回 Codex 重新拆模組
   - 不可先派工再補驗收

3. `fail_dependency_graph`
   - 退回 Codex 修依賴圖
   - 必須先解除循環依賴

4. `fail_dispatch_readiness`
   - 檢查是否可透過縮小路徑、調整 agent、補 acceptance commands 修正

5. `fail_preflight_handoff`
   - 退回 Codex 修正 `dispatch_policy`
   - Dispatcher 不可跳過 Wrapper 預檢直接派工

---

## 12. 建議驗證順序

實務上建議固定順序：

1. UTF-8 讀取
2. JSON parse
3. JSON Schema validate
4. 模組責任檢查
5. 輸入輸出副作用檢查
6. 依賴圖檢查
7. 路徑與派工可行性檢查
8. 檢查 preflight handoff 規則
9. 產出 validation result

不要顛倒順序，避免在結構錯誤時先做語意推論。

---

## 13. 最小派工門檻

只有在以下條件全部成立時，manifest 才可派工：

1. UTF-8 可正常讀取
2. JSON Schema 驗證通過
3. 每個模組具單一職責
4. 每個模組可獨立驗收
5. 所有依賴均存在且無循環
6. 副作用完整聲明
7. `allowed_paths` 合理
8. acceptance commands 足以驗證
9. `dispatch_policy` 完整，且 runtime preflight 不會被省略

---

## 14. 與其他文件的關係

本文件應搭配以下文件使用：

1. `../AGENTS.md`
2. `execution-manifest-spec.md`
3. `execution-manifest.schema.json`
4. `execution-manifest-validation-result-template.json`
5. `worker-preflight-result-template.json`

文件分工：

1. `AGENTS.md`：原則與硬規則
2. `execution-manifest-spec.md`：欄位語意與範例
3. `execution-manifest.schema.json`：結構驗證
4. `execution-manifest-validation-result-template.json`：驗證結果輸出範本
5. `worker-preflight-result-template.json`：runtime preflight 結果範本
5. 本文件：驗證順序與判斷流程
