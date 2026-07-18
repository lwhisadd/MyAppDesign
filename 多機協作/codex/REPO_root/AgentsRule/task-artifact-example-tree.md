# Task 目錄範例樹

本文件提供標準 `task` 產物目錄的範例樹，讓 agents、Codex、Dispatcher 與人工審查者可以直接依樣建立目錄與檔案。

所有文字檔、JSON 檔、Markdown 檔、設定檔，預設編碼一律使用 `UTF-8`。

---

## 1. 最小可接受範例

以下是單一 task 的最小可接受目錄結構：

```text
TASK-20260718-001/
├── task-envelope.json
├── execution-manifest.json
├── manifest-validation-result.json
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

適用情境：

1. 單一 task
2. 模組數量不多
3. 不需要額外拆分模組級產物

---

## 2. 建議的擴充範例

若 task 涉及多模組、較長執行期、或需要更細的驗證與審查產物，建議採用以下結構：

```text
TASK-20260718-001/
├── task-envelope.json
├── execution-manifest.json
├── manifest-validation-result.json
├── result.json
├── changed-files.txt
├── changes.patch
├── acceptance.json
├── codex-review.json
├── codex-review.md
├── logs/
│   ├── dispatcher.stderr
│   ├── worker.stdout
│   └── worker.stderr
├── modules/
│   ├── orders.route.query.validation.json
│   ├── orders.route.query.review.json
│   ├── orders.service.query.validation.json
│   ├── orders.service.query.review.json
│   ├── orders.repository.find_by_id.validation.json
│   └── orders.repository.find_by_id.review.json
├── manifests/
│   ├── execution-manifest.v1.json
│   └── execution-manifest.v2.json
└── reports/
    ├── human-summary.md
    └── risk-notes.md
```

適用情境：

1. 同一 task 有多個模組
2. manifest 經過多次修訂
3. 需要模組級驗證或審查結果
4. 需要人類可讀補充報告

---

## 3. 檔名範例

### 核心檔案

固定使用：

- `task-envelope.json`
- `execution-manifest.json`
- `manifest-validation-result.json`
- `result.json`
- `acceptance.json`
- `codex-review.json`
- `codex-review.md`

### 模組級檔案

建議格式：

```text
<module_id>.<artifact-type>.json
```

例如：

- `orders.route.query.validation.json`
- `orders.route.query.review.json`
- `orders.service.query.acceptance.json`
- `orders.repository.find_by_id.validation.json`

### 多版本 manifest

建議格式：

- `execution-manifest.v1.json`
- `execution-manifest.v2.json`
- `execution-manifest.v3.json`

不建議格式：

- `manifest-final-final.json`
- `manifest-new-ok.json`
- `manifest(2).json`

---

## 4. 目錄用途說明

### `logs/`

保存執行過程輸出：

- `dispatcher.stderr`
- `worker.stdout`
- `worker.stderr`

### `modules/`

保存模組級驗證、驗收、審查與補充結果。

### `manifests/`

保存多版本 manifest，供追溯修訂歷程使用。

### `reports/`

保存人類可讀補充說明，例如：

- 摘要
- 風險說明
- 後續待辦

---

## 5. 完成時至少應留下哪些檔案

無論採用最小結構或擴充結構，task 完成時至少應保留：

1. `execution-manifest.json`
2. `manifest-validation-result.json`
3. `result.json`
4. `acceptance.json`
5. `codex-review.json`
6. `codex-review.md`
7. `changed-files.txt`
8. `changes.patch`

---

## 6. 不可接受的情況

以下情況都不應發生：

1. 檔案只存在對話紀錄，未落地保存
2. `execution manifest` 有多個版本，但沒有明確版本檔名
3. review 只有 Markdown，沒有機器可讀 JSON
4. 只有 `worker.stdout`，沒有 `manifest-validation-result.json`
5. patch 沒有保存

---

## 7. 與其他文件的關係

本文件應搭配以下文件使用：

1. `多機協作/codex/AGENTS.md`
2. `多機協作/codex/task-artifact-structure.md`
3. `多機協作/codex/execution-manifest-validation-result-template.json`

文件分工：

1. `AGENTS.md`：定義硬規則與交付要求
2. `task-artifact-structure.md`：定義目錄與檔名規範
3. 本文件：提供可直接照抄的範例樹
