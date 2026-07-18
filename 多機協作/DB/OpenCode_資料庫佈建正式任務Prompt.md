# OpenCode 正式任務 Prompt：Hermes / Codex 協作資料庫佈建

你現在是負責「資料庫實作與佈建」的執行 agent。  
你的目標不是討論設計，而是依照既有文件，實際完成 SQLite MVP 的佈建、驗證與交付。

---

## 1. 你要讀的文件

先完整閱讀以下文件，再開始動作：

1. `多機協作/Hermes_Codex_資料庫實作佈建指南.md`
2. `多機協作/Hermes_Codex_多機Agent協作最終佈建報告.md`

以 `Hermes_Codex_資料庫實作佈建指南.md` 為施工主文件。  
若兩份文件有層級差異：

- 架構與角色分工以「最終佈建報告」為準
- 資料庫表結構、migration、驗證流程以「資料庫實作佈建指南」為準

---

## 2. 任務目標

你必須完成以下工作：

1. 在 `ctrl-hermes` 的規劃位置建立 SQLite 資料庫。
2. 建立初始化 migration SQL 檔。
3. 建立三張核心表：
   - `task_envelopes`
   - `task_executions`
   - `worker_state`
4. 建立文件要求的索引。
5. 驗證 schema 已正確建立。
6. 執行 smoke test，確認可寫入且可 rollback。
7. 回報實際成果、路徑、命令與驗證結果。

---

## 3. 目標主機與預設路徑

除非現場已有更明確既定路徑，否則使用以下預設：

- 目標主機：`ctrl-hermes`
- SQLite DB：`/srv/hermes-control/state/coordination.db`
- Migration SQL：`/srv/hermes-control/schemas/001_init_sqlite.sql`

---

## 4. 執行限制

你必須遵守以下限制：

1. 不要自行修改資料模型意義。
2. 不要把 secrets、API keys、OAuth token、SSH 私鑰寫入資料表。
3. 不要把 Hermes Memory 當成資料庫替代品。
4. 不要省略索引建立。
5. 不要只建立檔案而不做 schema 驗證。
6. 不要只做 schema 驗證而不做 smoke test。
7. 若發現環境缺少 `sqlite3`、路徑不可寫、或目標主機不可達，必須明確回報阻塞原因。
8. 若現場已有舊 `tasks` 單表，不可直接刪除；先依指南提出或執行遷移策略。

---

## 5. 必做步驟

請依序完成：

### Step 1. 閱讀文件並整理施工計劃

先讀完兩份文件，確認：

- DB 的角色是「真實狀態來源」
- 任務模型是二段式：
  - Hermes 建立 `task envelope`
  - Codex 產生 `execution manifest`

### Step 2. 前置檢查

至少檢查以下項目：

```bash
sqlite3 --version
test -d /srv/hermes-control/state
test -d /srv/hermes-control/schemas
```

若目錄不存在，請建立符合指南的目錄與權限。

### Step 3. 寫入 migration SQL

建立：

```text
/srv/hermes-control/schemas/001_init_sqlite.sql
```

內容必須符合 `Hermes_Codex_資料庫實作佈建指南.md` 的 migration draft。

### Step 4. 建立 SQLite DB

執行：

```bash
sqlite3 /srv/hermes-control/state/coordination.db < /srv/hermes-control/schemas/001_init_sqlite.sql
```

### Step 5. 驗證 schema

至少執行以下檢查：

```bash
sqlite3 /srv/hermes-control/state/coordination.db ".tables"
sqlite3 /srv/hermes-control/state/coordination.db ".schema task_envelopes"
sqlite3 /srv/hermes-control/state/coordination.db ".schema task_executions"
sqlite3 /srv/hermes-control/state/coordination.db ".schema worker_state"
sqlite3 /srv/hermes-control/state/coordination.db "PRAGMA index_list('task_envelopes');"
sqlite3 /srv/hermes-control/state/coordination.db "PRAGMA index_list('task_executions');"
sqlite3 /srv/hermes-control/state/coordination.db "PRAGMA index_list('worker_state');"
```

### Step 6. 執行 smoke test

你必須用交易包住測試資料並 rollback，驗證：

- `task_envelopes` 可插入
- `task_executions` 可插入
- `worker_state` 可插入
- 外鍵與非空欄位設計沒有立即性錯誤

### Step 7. 權限檢查

確認以下結果合理：

- `/srv/hermes-control/state`
- `/srv/hermes-control/schemas`
- `coordination.db`
- `001_init_sqlite.sql`

### Step 8. 若現場已有舊表，補充遷移建議

如果存在舊 `tasks` 單表，請不要刪除。  
你要：

1. 說明是否偵測到舊表
2. 說明是否已做新表建立
3. 說明舊資料應如何映射
4. 若未遷移，清楚標示為後續工作

---

## 6. 完成定義

只有在以下條件全部成立時，才能回報完成：

1. `coordination.db` 已建立
2. `001_init_sqlite.sql` 已建立
3. 三張核心表存在
4. 必要索引存在
5. schema 驗證通過
6. smoke test 通過
7. 權限檢查完成
8. 若有舊 `tasks` 單表，已提出明確遷移說明

---

## 7. 回報格式

完成後請用以下格式回報：

### A. 結果摘要

- `completed` / `blocked`
- 實際建置主機
- 實際 DB 路徑
- 實際 migration 路徑

### B. 已完成項目

- 建立了哪些檔案
- 建立了哪些表
- 建立了哪些索引
- smoke test 是否通過

### C. 驗證摘要

- `.tables` 結果摘要
- 三張表 schema 是否存在
- 索引檢查結果
- 權限檢查結果

### D. 風險或阻塞

- 缺少套件
- 路徑不可寫
- 舊表衝突
- 主機不可達
- 任何未完成但需要人工處理的事項

### E. 產出清單

- `001_init_sqlite.sql`
- `coordination.db`
- 若有補充文件，一併列出

---

## 8. 若你被阻塞

若任一步驟無法完成，不要只說「失敗」。  
請明確指出：

1. 卡在哪一步
2. 你已經做了哪些檢查
3. 缺的是權限、工具、路徑、主機連線，還是現場資料狀態
4. 下一步需要誰處理

---

## 9. 執行原則

以「直接可驗證的建置結果」為優先，不要只回報推論。  
你的完成證明必須是：

- 實際檔案
- 實際資料庫
- 實際 schema
- 實際驗證結果

不是口頭說明而已。
