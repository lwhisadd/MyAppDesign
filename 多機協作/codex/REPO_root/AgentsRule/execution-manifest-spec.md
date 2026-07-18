# Execution Manifest 規格說明

本文件定義 `execution manifest` 的欄位格式、語意、模組拆分規則、依賴表示方式與範例。

本文件用途：

1. 提供 `ctrl-codex` 產生 `execution manifest` 時的格式依據
2. 提供 Dispatcher、Worker、驗收流程理解任務結構的共同規格
3. 搭配 `execution-manifest.schema.json` 作為人類可讀規格

所有文字檔、JSON 檔與範例內容，預設編碼一律使用 `UTF-8`。

---

## 1. 文件定位

在 Hermes + Codex 多機協作流程中：

1. Hermes 建立 `task envelope`
2. Codex 讀取 `task envelope`、分析 repository、拆分模組
3. Codex 產生 `execution manifest`
4. Codex 在 manifest 中定義 `dispatch_policy`
5. Wrapper 根據 `dispatch_policy` 執行 runtime preflight
6. Dispatcher 根據 `execution manifest`、validation result、preflight result 決定是否派工
7. Worker 執行模組工作
8. Codex 驗收各模組產出與整體結果

`execution manifest` 是工程執行真相來源，不是單純備忘錄。

---

## 2. 設計原則

`execution manifest` 必須符合以下原則：

1. 功能必須拆成最小可獨立驗收的模組單元。
2. 每個模組只能對應單一明確職責。
3. 不可把多個不相關變更合併進同一模組。
4. 每個模組都必須清楚描述輸入、輸出、副作用。
5. 每個模組都必須標示上層依賴與下層依賴。
6. 模組集合必須形成可追溯依賴圖。
7. 若存在循環依賴、責任重疊或拆分不完整，必須在 manifest 產生階段修正。
8. 所有影響實作方向的技術選型，必須在 manifest 中明確列入其決策來源。
9. 若任務預設要求 `TDD`，必須在 manifest 中清楚標示；若不適用，必須寫明例外理由與替代驗證方式。
10. 若要求將重構與行為變更分離，manifest 應明確聲明 commit 規則。
11. manifest 必須明確聲明 runtime preflight 的責任分工與必要檢查，不可把即時 quota / auth 探測責任模糊留給 Worker 自行決定。

---

## 3. Top-Level 結構

`execution manifest` 建議使用以下 top-level 欄位：

```json
{
  "schema_version": "1.0.0",
  "task_id": "TASK-20260718-001",
  "project": "YOUR_REPO",
  "request": "新增訂單查詢 API 並補測試",
  "tech_decisions": [
    {
      "topic": "frontend-framework",
      "decision": "Next.js App Router",
      "source": "前台選型/討論1.md"
    }
  ],
  "development_process": {
    "tdd_required": true,
    "tdd_exception_reason": "",
    "verification_strategy": "unit-and-integration-tests"
  },
  "commit_rules": {
    "separate_refactor_from_behavior": true
  },
  "dispatch_policy": {
    "preflight_required": true,
    "preflight_rule_owner": "ctrl-codex",
    "preflight_execution_owner": "wrapper",
    "dispatch_execution_owner": "dispatcher",
    "required_checks": ["health", "auth", "quota", "cooldown", "rate_limit"],
    "block_dispatch_when_unavailable": true
  },
  "base_ref": "origin/main",
  "allowed_paths": ["src/orders", "tests/orders"],
  "denied_paths": [".git", ".github/workflows", ".env", "secrets"],
  "acceptance_commands": ["npm run lint", "npm run typecheck", "npm test"],
  "timeout_seconds": 3600,
  "must_commit": true,
  "fallback_agents": ["claude", "codex"],
  "modules": []
}
```

欄位說明：

- `schema_version`：規格版本
- `task_id`：任務唯一 ID
- `project`：專案名稱或識別值
- `request`：使用者需求摘要
- `tech_decisions`：本次任務依賴的技術選型與其決策來源
- `development_process`：開發流程要求，例如是否強制 TDD、若例外時的理由、替代驗證策略
- `commit_rules`：commit 層級規則，例如是否分離重構與行為變更
- `dispatch_policy`：派工前預檢規則與責任分工，明確區分 `ctrl-codex`、Wrapper、Dispatcher 的責任
- `base_ref`：基準分支或 ref
- `allowed_paths`：允許修改路徑
- `denied_paths`：禁止修改路徑
- `acceptance_commands`：整體驗收命令
- `timeout_seconds`：整體任務超時
- `must_commit`：是否必須產生 commit
- `fallback_agents`：頂層 fallback agent 清單
- `modules`：模組列表

建議 `dispatch_policy` 結構：

```json
{
  "preflight_required": true,
  "preflight_rule_owner": "ctrl-codex",
  "preflight_execution_owner": "wrapper",
  "dispatch_execution_owner": "dispatcher",
  "required_checks": ["health", "auth", "quota", "cooldown", "rate_limit"],
  "block_dispatch_when_unavailable": true
}
```

欄位說明：

- `preflight_required`：是否要求 runtime preflight
- `preflight_rule_owner`：預檢規則制定者，固定為 `ctrl-codex`
- `preflight_execution_owner`：預檢執行者，固定為 `wrapper`
- `dispatch_execution_owner`：派工執行者，固定為 `dispatcher`
- `required_checks`：派工前必查項目
- `block_dispatch_when_unavailable`：若預檢失敗，是否必須阻止正式派工

---

## 4. 模組物件結構

每個模組至少應包含以下欄位：

```json
{
  "module_id": "orders.query.api",
  "name": "訂單查詢 API",
  "responsibility": "提供單筆訂單查詢 HTTP API",
  "description": "新增查詢端點並串接既有查詢服務",
  "inputs": [],
  "outputs": [],
  "side_effects": [],
  "upstream_dependencies": [],
  "downstream_dependencies": [],
  "allowed_paths": ["src/orders", "tests/orders"],
  "acceptance_commands": ["npm test -- orders"],
  "preferred_agent": "opencode",
  "fallback_agents": ["claude", "codex"]
}
```

欄位說明：

- `module_id`：模組唯一識別值，建議使用點分層命名
- `name`：短名稱
- `responsibility`：單一職責描述
- `description`：補充說明
- `inputs`：模組輸入清單
- `outputs`：模組輸出清單
- `side_effects`：副作用清單
- `upstream_dependencies`：會呼叫此模組的上層模組
- `downstream_dependencies`：此模組會呼叫的下層模組
- `allowed_paths`：模組級可修改路徑
- `acceptance_commands`：模組級驗收命令
- `preferred_agent`：優先執行 agent
- `fallback_agents`：模組級 fallback agent

---

## 5. `inputs` 欄位格式

每個輸入項目必須包含：

```json
{
  "name": "order_id",
  "type": "string",
  "source": "http request path",
  "required": true,
  "description": "欲查詢的訂單編號"
}
```

欄位說明：

- `name`：輸入名稱
- `type`：資料型別，例如 `string`、`number`、`boolean`、`json`、`file`、`sql-row`
- `source`：來源描述，例如 `http request body`、`database`、`config file`
- `required`：是否必填
- `description`：補充說明

---

## 6. `outputs` 欄位格式

每個輸出項目必須包含：

```json
{
  "name": "response_body",
  "type": "json",
  "kind": "return",
  "target": "HTTP 200 response",
  "description": "訂單查詢結果"
}
```

欄位說明：

- `name`：輸出名稱
- `type`：資料型別
- `kind`：輸出類型，建議值：
  - `file`
  - `return`
  - `event`
  - `db-write`
  - `log`
- `target`：輸出落點，例如檔案路徑、回傳位置、資料表
- `description`：補充說明

---

## 7. `side_effects` 欄位格式

若模組執行會產生副作用，必須列出：

```json
{
  "type": "db-write",
  "target": "orders table",
  "description": "更新查詢快取時間"
}
```

常見副作用類型：

- `db-write`
- `file-write`
- `network-call`
- `cache-invalidate`
- `queue-publish`
- `state-transition`

若模組無副作用，應填空陣列 `[]`，不可省略欄位。

---

## 8. 依賴圖規則

每個模組必須同時描述：

1. `upstream_dependencies`
2. `downstream_dependencies`

規則如下：

1. 若 A 的 `downstream_dependencies` 包含 B，則 B 的 `upstream_dependencies` 應包含 A。
2. 依賴名稱必須使用既有 `module_id`。
3. 不可引用不存在的模組。
4. 不可形成循環依賴。
5. 不可把單純同檔案修改關係誤寫成依賴關係。

---

## 9. 不可接受的情況

以下情況都視為不合格 manifest：

1. 同一模組同時修改 API、資料庫 migration、UI 文案且三者無單一責任中心
2. 模組未列出輸入與輸出
3. 模組有副作用但未聲明
4. `upstream_dependencies` / `downstream_dependencies` 不一致
5. 存在循環依賴
6. 模組無法獨立驗收
7. 模組描述只寫「修改訂單功能」這種過度籠統內容

---

## 10. 完整範例

```json
{
  "schema_version": "1.0.0",
  "task_id": "TASK-20260718-001",
  "project": "YOUR_REPO",
  "request": "新增訂單查詢 API 並補測試",
  "tech_decisions": [
    {
      "topic": "backend-api",
      "decision": "EasyAPI as the only REST API",
      "source": "前台選型/討論1.md"
    }
  ],
  "development_process": {
    "tdd_required": true,
    "tdd_exception_reason": "",
    "verification_strategy": "unit-and-integration-tests"
  },
  "commit_rules": {
    "separate_refactor_from_behavior": true
  },
  "dispatch_policy": {
    "preflight_required": true,
    "preflight_rule_owner": "ctrl-codex",
    "preflight_execution_owner": "wrapper",
    "dispatch_execution_owner": "dispatcher",
    "required_checks": ["health", "auth", "quota", "cooldown", "rate_limit"],
    "block_dispatch_when_unavailable": true
  },
  "base_ref": "origin/main",
  "allowed_paths": ["src/orders", "tests/orders"],
  "denied_paths": [".git", ".github/workflows", ".env", "secrets"],
  "acceptance_commands": ["npm run lint", "npm run typecheck", "npm test"],
  "timeout_seconds": 3600,
  "must_commit": true,
  "fallback_agents": ["claude", "codex"],
  "modules": [
    {
      "module_id": "orders.route.query",
      "name": "訂單查詢路由",
      "responsibility": "提供訂單查詢 API 路由入口",
      "description": "建立 GET /orders/:id 路由並交由 service 層處理",
      "inputs": [
        {
          "name": "order_id",
          "type": "string",
          "source": "http request path",
          "required": true,
          "description": "訂單編號"
        }
      ],
      "outputs": [
        {
          "name": "response_body",
          "type": "json",
          "kind": "return",
          "target": "HTTP response",
          "description": "回傳訂單資料"
        }
      ],
      "side_effects": [],
      "upstream_dependencies": [],
      "downstream_dependencies": ["orders.service.query"],
      "allowed_paths": ["src/orders/routes", "tests/orders/routes"],
      "acceptance_commands": ["npm test -- orders-route"],
      "preferred_agent": "opencode",
      "fallback_agents": ["claude", "codex"]
    },
    {
      "module_id": "orders.service.query",
      "name": "訂單查詢服務",
      "responsibility": "查詢訂單資料並回傳標準結構",
      "description": "封裝訂單查詢服務邏輯",
      "inputs": [
        {
          "name": "order_id",
          "type": "string",
          "source": "orders.route.query",
          "required": true,
          "description": "訂單編號"
        }
      ],
      "outputs": [
        {
          "name": "order_payload",
          "type": "json",
          "kind": "return",
          "target": "service return value",
          "description": "標準化訂單資料"
        }
      ],
      "side_effects": [],
      "upstream_dependencies": ["orders.route.query"],
      "downstream_dependencies": ["orders.repository.find_by_id"],
      "allowed_paths": ["src/orders/services", "tests/orders/services"],
      "acceptance_commands": ["npm test -- orders-service"],
      "preferred_agent": "claude",
      "fallback_agents": ["opencode", "codex"]
    },
    {
      "module_id": "orders.repository.find_by_id",
      "name": "訂單資料存取",
      "responsibility": "依訂單編號查詢資料來源",
      "description": "從 repository 層存取訂單資料",
      "inputs": [
        {
          "name": "order_id",
          "type": "string",
          "source": "orders.service.query",
          "required": true,
          "description": "訂單編號"
        }
      ],
      "outputs": [
        {
          "name": "order_record",
          "type": "json",
          "kind": "return",
          "target": "repository return value",
          "description": "原始資料記錄"
        }
      ],
      "side_effects": [],
      "upstream_dependencies": ["orders.service.query"],
      "downstream_dependencies": [],
      "allowed_paths": ["src/orders/repositories", "tests/orders/repositories"],
      "acceptance_commands": ["npm test -- orders-repository"],
      "preferred_agent": "opencode",
      "fallback_agents": ["claude", "codex"]
    }
  ]
}
```

---

## 11. 驗收前檢查清單

在 manifest 產生完成後，至少檢查：

1. 每個模組是否可獨立驗收
2. 每個模組是否只有單一職責
3. 是否有未聲明副作用
4. 是否存在循環依賴
5. 是否存在責任重疊
6. 模組依賴圖是否完整
7. `allowed_paths` 是否過寬
8. `acceptance_commands` 是否足以驗證模組
9. `tech_decisions` 是否足以追溯本次任務依賴的技術選型
10. `development_process` 是否明確說明 TDD 要求或例外原因
11. `commit_rules` 是否足以限制重構與行為變更混雜
12. `dispatch_policy` 是否明確指定預檢規則制定者、執行者、派工執行者與必要檢查

---

## 12. 與 Schema 的關係

`execution-manifest.schema.json` 負責結構驗證。  
本文件負責語意規則與設計意圖說明。

以下規則通常無法只靠 JSON Schema 完整驗證，必須由 Codex 額外檢查：

1. 單一職責是否成立
2. 模組是否可獨立驗收
3. 是否存在職責重疊
4. 是否存在循環依賴
5. 輸入、輸出與副作用的描述是否合理
