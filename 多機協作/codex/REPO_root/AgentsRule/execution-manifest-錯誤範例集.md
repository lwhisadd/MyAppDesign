# Execution Manifest 錯誤範例集

本文件提供常見的 `execution manifest` 錯誤範例，目的是幫助 `ctrl-codex`、Worker、人工審查者快速辨識不合格的 manifest。

所有文字檔與 JSON 範例，預設編碼一律使用 `UTF-8`。

---

## 1. 使用方式

本文件用途：

1. 協助 Codex 在產生 manifest 時自我檢查
2. 協助 Dispatcher 或驗收流程判斷 manifest 是否應退回修正
3. 協助人工審查辨識常見建模錯誤

若 manifest 命中本文件中的任一高風險錯誤，應在派工前修正，不得留到驗收階段。

---

## 2. 錯誤類型總覽

常見不合格情況：

1. 模組責任混雜
2. 模組不可獨立驗收
3. 輸入不完整
4. 輸出不完整
5. 副作用未聲明
6. 依賴不存在
7. 循環依賴
8. 路徑範圍過寬
9. 驗收命令不足
10. 結構符合 schema，但語意不合理

---

## 3. 錯誤範例

### 範例 A：同一模組混入多個不相關職責

```json
{
  "module_id": "orders.all-in-one",
  "name": "訂單全部修改",
  "responsibility": "新增查詢 API、修改資料庫 migration、更新前台顯示文案",
  "inputs": [],
  "outputs": [],
  "side_effects": [],
  "upstream_dependencies": [],
  "downstream_dependencies": [],
  "allowed_paths": ["src/orders", "db/migrations", "src/frontend"],
  "acceptance_commands": ["npm test"],
  "preferred_agent": "claude",
  "fallback_agents": ["opencode", "codex"]
}
```

問題：

1. 同時混入 API、migration、前端文案三種不同責任
2. 不符合 single responsibility
3. 無法作為最小可獨立驗收模組

應修正為：

1. `orders.route.query`
2. `orders.service.query`
3. `orders.db.migration.add_index`
4. `orders.ui.copy.update`

---

### 範例 B：模組沒有可驗收邊界

```json
{
  "module_id": "orders.fix",
  "name": "修一下訂單",
  "responsibility": "修正訂單功能",
  "description": "讓它正常",
  "inputs": [],
  "outputs": [],
  "side_effects": [],
  "upstream_dependencies": [],
  "downstream_dependencies": [],
  "allowed_paths": ["src/orders"],
  "acceptance_commands": ["npm test"],
  "preferred_agent": "opencode",
  "fallback_agents": ["claude"]
}
```

問題：

1. 職責描述過於模糊
2. 無法判斷模組要修改什麼
3. 無法獨立驗收
4. `outputs` 為空，缺少完成定義

---

### 範例 C：輸入缺少型別與來源

```json
{
  "module_id": "orders.service.query",
  "name": "訂單查詢服務",
  "responsibility": "查詢訂單",
  "description": "查詢服務",
  "inputs": [
    {
      "name": "order_id"
    }
  ],
  "outputs": [
    {
      "name": "order_payload",
      "type": "json",
      "kind": "return",
      "target": "service return value",
      "description": "查詢結果"
    }
  ],
  "side_effects": [],
  "upstream_dependencies": [],
  "downstream_dependencies": [],
  "allowed_paths": ["src/orders/services"],
  "acceptance_commands": ["npm test -- orders-service"],
  "preferred_agent": "opencode",
  "fallback_agents": ["claude"]
}
```

問題：

1. `inputs` 缺少 `type`
2. 缺少 `source`
3. 缺少 `required`
4. 缺少 `description`

---

### 範例 D：副作用未聲明

```json
{
  "module_id": "orders.cache.refresh",
  "name": "更新查詢快取",
  "responsibility": "刷新訂單快取",
  "description": "查詢後刷新快取",
  "inputs": [
    {
      "name": "order_payload",
      "type": "json",
      "source": "orders.service.query",
      "required": true,
      "description": "訂單資料"
    }
  ],
  "outputs": [
    {
      "name": "cache_status",
      "type": "string",
      "kind": "return",
      "target": "service return value",
      "description": "快取刷新狀態"
    }
  ],
  "side_effects": [],
  "upstream_dependencies": ["orders.service.query"],
  "downstream_dependencies": [],
  "allowed_paths": ["src/orders/cache"],
  "acceptance_commands": ["npm test -- orders-cache"],
  "preferred_agent": "opencode",
  "fallback_agents": ["claude"]
}
```

問題：

1. 實際上有 cache 寫入副作用
2. `side_effects` 卻留空
3. 驗收時容易漏掉外部狀態變化

---

### 範例 E：依賴不存在

```json
{
  "module_id": "orders.route.query",
  "name": "訂單查詢路由",
  "responsibility": "建立查詢路由",
  "description": "新增 GET /orders/:id",
  "inputs": [],
  "outputs": [
    {
      "name": "response_body",
      "type": "json",
      "kind": "return",
      "target": "HTTP response",
      "description": "查詢回應"
    }
  ],
  "side_effects": [],
  "upstream_dependencies": [],
  "downstream_dependencies": ["orders.service.query", "orders.validator.missing"],
  "allowed_paths": ["src/orders/routes"],
  "acceptance_commands": ["npm test -- orders-route"],
  "preferred_agent": "opencode",
  "fallback_agents": ["claude"]
}
```

問題：

1. `orders.validator.missing` 並不存在於模組列表
2. 依賴圖不完整

---

### 範例 F：循環依賴

```text
orders.route.query
  -> orders.service.query

orders.service.query
  -> orders.repository.find_by_id

orders.repository.find_by_id
  -> orders.route.query
```

問題：

1. 形成循環依賴
2. 無法正確排序執行或推導模組邊界
3. 代表模組拆分或責任分配有誤

處理原則：

1. 先檢查是否把資料流誤寫成控制流依賴
2. 若確有循環，必須重新拆模組或抽出介面層

---

### 範例 G：`allowed_paths` 過寬

```json
{
  "module_id": "orders.service.query",
  "allowed_paths": ["src", "tests", "scripts", ".github"]
}
```

問題：

1. 路徑範圍過寬
2. 不利於隔離變更
3. 提高越界修改風險

建議：

1. 只保留實際需要的子路徑
2. 若需要多處修改，應先確認是否屬於同一責任

---

### 範例 H：模組級驗收命令不足

```json
{
  "module_id": "orders.db.migration.add_index",
  "acceptance_commands": ["npm test"]
}
```

問題：

1. migration 模組只有通用測試，缺少 migration 驗證
2. 無法確認 schema 變更是否正確

建議：

1. 補充 migration dry-run 或 schema diff 檢查
2. 若有資料風險，補充 rollback 或驗證步驟

---

## 4. Schema 通過但仍可能不合格的情況

以下情況可能通過 JSON Schema，但仍應判定為不合格：

1. 模組名稱與責任描述雖有值，但實際非常模糊
2. 依賴圖語法正確，但語意上明顯循環
3. `side_effects` 已填，但內容與實際工作不符
4. `allowed_paths` 合法，但範圍大到失去隔離意義
5. `acceptance_commands` 格式正確，但根本不足以驗證模組

---

## 5. 快速審查清單

看到 manifest 時，至少快速檢查：

1. 模組數量是否合理，是否有明顯 all-in-one 模組
2. 每個模組是否有單一職責句子
3. `inputs` / `outputs` / `side_effects` 是否完整
4. 依賴是否都能對應到真實模組
5. 是否能畫出無循環依賴圖
6. 每個模組是否都有明確驗收方法

---

## 6. 結論

只要 manifest 出現：

1. 單一模組承擔多個不相關責任
2. 缺少輸入輸出副作用說明
3. 存在依賴錯誤或循環依賴
4. 無法獨立驗收

就應在 manifest 產生階段退回修正，不得直接派工。
