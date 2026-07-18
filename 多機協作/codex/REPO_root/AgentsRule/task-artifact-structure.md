# Task 產物目錄與檔名規範

本文件定義每個 `task_id` 對應的產物目錄結構、檔名慣例、保存要求與最小交付集合。

本文件用途：

1. 提供 `ctrl-codex`、Dispatcher、Worker、人工審查者一致的 task 產物結構
2. 確保 `execution manifest`、validation result、review result、摘要與日誌不只存在對話或終端
3. 讓 task 結果可追溯、可審計、可回放

所有文字檔、JSON 檔、Markdown 檔、設定檔，預設編碼一律使用 `UTF-8`。

---

## 1. 目錄定位

每個 task 都應有獨立目錄，建議放在：

```text
/srv/codex-supervisor/results/TASK-ID/
```

若由 Hermes 控制平面集中保存，也可映射到：

```text
/srv/hermes-control/logs/TASK-ID/
```

無論採用哪個根目錄，單一 `task_id` 的所有關鍵產物都必須集中保存於同一 task 目錄。

---

## 2. 標準目錄結構

建議最小結構：

```text
TASK-ID/
├── task-envelope.json
├── execution-manifest.json
├── manifest-validation-result.json
├── worker-preflight-result.json
├── dispatcher.stderr
├── worker.stdout
├── worker.stderr
├── result.json
├── changed-files.txt
├── changes.patch
├── acceptance.json
├── codex-review.json
└── codex-review.md
```

若 task 涉及多模組或多階段，也可擴充：

```text
TASK-ID/
├── artifacts/
├── manifests/
├── reviews/
├── logs/
└── reports/
```

但即使擴充，也應保持核心檔名與用途不變。

---

## 3. 核心檔案定義

### `task-envelope.json`

用途：

- 保存 Hermes 建立的 task envelope
- 作為需求來源與流程控制資訊依據

### `execution-manifest.json`

用途：

- 保存 Codex 產生的 execution manifest
- 作為派工與工程執行的主描述檔

### `manifest-validation-result.json`

用途：

- 保存 manifest 驗證結果
- 派工前必須先存在

要求：

- 其內容應盡量符合 `execution-manifest-validation-result-template.json`
- 若 `dispatch_allowed != true`，禁止派工

### `worker-preflight-result.json`

用途：

- 保存 Wrapper 執行 runtime preflight 的結果
- 作為 Dispatcher 是否正式派工的直接依據

要求：

- 其內容應盡量符合 `worker-preflight-result-template.json`
- 若 `preflight.available != true`，禁止正式派工

### `dispatcher.stderr`

用途：

- 保存 Dispatcher 錯誤輸出

### `worker.stdout`

用途：

- 保存 Worker 標準輸出

### `worker.stderr`

用途：

- 保存 Worker 錯誤輸出

### `result.json`

用途：

- 保存 Worker 執行結果摘要
- 通常對應 wrapper 回傳的結構化結果

### `changed-files.txt`

用途：

- 保存本 task 實際修改的檔案清單

### `changes.patch`

用途：

- 保存完整 patch
- 供驗收、追蹤、回放或審計使用

### `acceptance.json`

用途：

- 保存 acceptance commands 執行結果

### `codex-review.json`

用途：

- 保存機器可讀的最終驗收結論

### `codex-review.md`

用途：

- 保存人類可讀的最終驗收摘要

---

## 4. 檔名慣例

原則：

1. 檔名使用固定命名，不要每個 task 自由命名
2. 檔名使用小寫英數、連字號、底線
3. 若是主檔案，優先使用固定檔名，不把 `task_id` 重複塞進檔名
4. 若需保留多版，可用版本尾碼：
   - `execution-manifest.v2.json`
   - `codex-review.v2.md`

不建議：

1. `final_result_latest_ok2.json`
2. `manifest_new_fixed_final.json`
3. `summary(1).md`

---

## 5. 保存規則

每個 task 至少必須保存以下四類產物：

1. 規劃產物
   - `task-envelope.json`
   - `execution-manifest.json`
   - `manifest-validation-result.json`
   - `worker-preflight-result.json`
2. 執行產物
   - `worker.stdout`
   - `worker.stderr`
   - `result.json`
3. 驗收產物
   - `acceptance.json`
   - `codex-review.json`
   - `codex-review.md`
4. 變更產物
   - `changed-files.txt`
   - `changes.patch`

不可接受情況：

1. manifest 只存在對話中
2. review 結果只存在終端輸出
3. acceptance 結果無獨立檔案
4. patch 未保存

---

## 6. 最小完成定義

task 若宣告完成，task 目錄至少必須存在：

1. `execution-manifest.json`
2. `manifest-validation-result.json`
3. `worker-preflight-result.json`
4. `result.json`
5. `acceptance.json`
6. `codex-review.json`
7. `codex-review.md`

若缺少上述任一項，視為交付不完整。

---

## 7. 多模組任務的擴充規則

若 task 內模組較多，可額外保存模組級產物，例如：

```text
TASK-ID/
├── modules/
│   ├── orders.route.query.review.json
│   ├── orders.service.query.review.json
│   └── orders.repository.find_by_id.review.json
```

建議檔名格式：

```text
<module_id>.<artifact-type>.json
```

例如：

- `orders.route.query.validation.json`
- `orders.service.query.review.json`
- `orders.repository.find_by_id.acceptance.json`

---

## 8. 安全要求

task 目錄中不得保存以下內容：

1. API key
2. OAuth token
3. SSH private key
4. 完整環境變數快照
5. 未遮蔽秘密

如需保留錯誤訊息，必須先做 secrets redaction。

---

## 9. 與其他文件的關係

本文件應搭配以下文件使用：

1. `../AGENTS.md`
2. `execution-manifest-spec.md`
3. `execution-manifest-驗證流程說明.md`
4. `execution-manifest-validation-result-template.json`
5. `worker-preflight-result-template.json`

文件分工：

1. `AGENTS.md`：硬規則與流程邊界
2. `execution-manifest-spec.md`：manifest 欄位與語意
3. `execution-manifest-驗證流程說明.md`：manifest 驗證流程
4. `worker-preflight-result-template.json`：runtime preflight 結果範本
5. 本文件：task 產物保存位置與檔名規範
