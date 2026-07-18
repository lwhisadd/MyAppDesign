# Hermes + Codex 多機協作資料庫實作佈建指南

> 文件用途：提供給負責資料庫工作的 agents，作為 SQLite MVP 佈建與驗證的直接執行說明。  
> 適用範圍：`Hermes` 控制平面、`Codex` 規劃與驗收流程、`Dispatcher / Worker Wrapper` 執行狀態保存。  
> 本文件目標：讓 agent 不需要回推設計意圖，就能完成資料庫建立、migration、驗證與交付。

---

## 1. 任務目標

本次資料庫工作要完成以下事項：

1. 建立 SQLite MVP 資料庫。
2. 建立三張核心資料表：
   - `task_envelopes`
   - `task_executions`
   - `worker_state`
3. 建立必要索引。
4. 明確支援二段式任務模型：
   - `Hermes` 建立 `task envelope`
   - `Codex` 產生 `execution manifest`
5. 讓資料庫成為真實狀態來源，避免 Hermes Memory 承擔調度真相。

---

## 2. 設計原則

agents 在實作時必須遵守以下原則：

1. `Memory` 只能作為輔助上下文，不可作為調度真相來源。
2. 所有會影響派工、驗收、quota、cooldown、阻塞、人工核准的狀態，必須寫入 DB。
3. `task_envelopes` 只保存流程真相，不保存工程推論。
4. `task_executions` 保存工程執行真相，不混入 Hermes 記憶性欄位。
5. `worker_state` 只描述 Worker 狀態，不替代 task 狀態。
6. MVP 階段使用 SQLite；未進入多控制節點與高併發前，不需要 PostgreSQL。

---

## 3. 建議佈建位置

建議使用以下路徑：

- SQLite DB 檔案：`/srv/hermes-control/state/coordination.db`
- Migration SQL：`/srv/hermes-control/schemas/001_init_sqlite.sql`

若現場已有既定路徑，可以調整，但必須滿足以下條件：

1. DB 檔案必須位於 Hermes 控制平面可讀寫目錄。
2. Schema 檔案必須納入版本控制或至少可追溯保存。
3. DB 檔案權限不得過度開放。

建議權限：

```bash
chmod 700 /srv/hermes-control/state
chmod 700 /srv/hermes-control/schemas
chmod 600 /srv/hermes-control/state/coordination.db
chmod 640 /srv/hermes-control/schemas/001_init_sqlite.sql
```

---

## 4. 需要建立的資料表

### 4.1 `task_envelopes`

用途：保存 Hermes 建立的流程級任務資訊。

```sql
CREATE TABLE IF NOT EXISTS task_envelopes (
  task_id TEXT PRIMARY KEY,
  project TEXT NOT NULL,
  request TEXT NOT NULL,
  source TEXT NOT NULL,
  priority TEXT NOT NULL DEFAULT 'normal',
  requires_human_approval INTEGER NOT NULL DEFAULT 0,
  approval_status TEXT NOT NULL DEFAULT 'not_required',
  approval_note TEXT,
  created_at TEXT NOT NULL,
  created_by TEXT,
  updated_at TEXT NOT NULL
);
```

欄位說明：

- `task_id`：任務唯一 ID，格式建議 `TASK-YYYYMMDD-NNN`
- `project`：專案識別值
- `request`：原始需求描述
- `source`：任務來源，建議值 `telegram` / `web` / `cli` / `api` / `manual`
- `priority`：建議值 `low` / `normal` / `high` / `urgent`
- `requires_human_approval`：是否需要人工核准，`0` 或 `1`
- `approval_status`：建議值 `not_required` / `pending` / `approved` / `rejected`
- `approval_note`：人工核准附註
- `created_at` / `updated_at`：ISO 8601 時間字串
- `created_by`：建立者識別值

### 4.2 `task_executions`

用途：保存 Codex、Dispatcher、Worker Wrapper 的工程執行真相。

```sql
CREATE TABLE IF NOT EXISTS task_executions (
  task_id TEXT PRIMARY KEY,
  project TEXT NOT NULL,
  current_phase TEXT NOT NULL,
  status TEXT NOT NULL,
  base_ref TEXT,
  base_sha TEXT,
  agent TEXT,
  worker_id TEXT,
  branch TEXT,
  worktree_path TEXT,
  prompt_path TEXT,
  execution_manifest_path TEXT,
  result_sha TEXT,
  result_path TEXT,
  fallback_agents_json TEXT,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  lease_owner TEXT,
  lease_expires_at TEXT,
  dispatched_at TEXT,
  started_at TEXT,
  finished_at TEXT,
  last_error TEXT,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (task_id) REFERENCES task_envelopes(task_id)
);
```

欄位說明：

- `current_phase`：任務目前所處階段
- `status`：任務整體摘要狀態
- `base_ref` / `base_sha`：執行時基準分支與 commit
- `agent`：建議值 `opencode` / `claude` / `antigravity` / `codex`
- `worker_id`：被指派的 Worker
- `branch`：任務隔離 branch
- `worktree_path`：工作目錄
- `prompt_path`：實際 prompt 檔案路徑
- `execution_manifest_path`：execution manifest 檔案路徑
- `result_sha` / `result_path`：最終產出定位資訊
- `fallback_agents_json`：fallback agent 清單，SQLite MVP 先以 JSON 字串保存
- `attempt_count`：重試次數
- `lease_owner` / `lease_expires_at`：為日後併發控制保留
- `dispatched_at` / `started_at` / `finished_at`：派工與執行時間
- `last_error`：最近一次執行錯誤摘要

### 4.3 `worker_state`

用途：保存 Worker 健康狀態、quota/cooldown 狀態與目前占用情形。

```sql
CREATE TABLE IF NOT EXISTS worker_state (
  worker_id TEXT PRIMARY KEY,
  agent TEXT NOT NULL,
  account_pool TEXT,
  enabled INTEGER NOT NULL DEFAULT 1,
  health TEXT NOT NULL DEFAULT 'unknown',
  current_task_id TEXT,
  quota_window TEXT,
  retry_after TEXT,
  last_probe_at TEXT,
  last_error TEXT,
  last_heartbeat_at TEXT,
  updated_at TEXT NOT NULL
);
```

欄位說明：

- `account_pool`：同帳號共享額度池識別值
- `enabled`：是否可派工
- `health`：建議值 `unknown` / `healthy` / `degraded` / `blocked` / `disabled`
- `current_task_id`：目前執行中的任務
- `quota_window`：建議值 `five_hour` / `weekly` / `daily` / `monthly` / `unknown`
- `retry_after`：下一次可 probe 或恢復派工的時間
- `last_probe_at`：最近一次健康或配額探測時間
- `last_heartbeat_at`：最近一次心跳

---

## 5. 必建索引

```sql
CREATE INDEX IF NOT EXISTS idx_task_envelopes_approval_status
  ON task_envelopes (approval_status);

CREATE INDEX IF NOT EXISTS idx_task_executions_status_phase
  ON task_executions (status, current_phase);

CREATE INDEX IF NOT EXISTS idx_task_executions_worker_id
  ON task_executions (worker_id);

CREATE INDEX IF NOT EXISTS idx_worker_state_agent_enabled
  ON worker_state (agent, enabled);

CREATE INDEX IF NOT EXISTS idx_worker_state_account_pool_retry_after
  ON worker_state (account_pool, retry_after);
```

目的：

- 加速人工核准查詢
- 加速派工與排隊查詢
- 加速同帳號 quota pool 判斷
- 加速 Worker 可用性查詢

---

## 6. 狀態定義

### 6.1 `approval_status`

建議固定值：

- `not_required`
- `pending`
- `approved`
- `rejected`

### 6.2 `current_phase`

建議固定值：

- `enveloped`
- `planned`
- `dispatched`
- `running`
- `reviewing`
- `accepted`
- `failed`
- `blocked`

### 6.3 `status`

建議固定值：

- `queued`
- `ready`
- `running`
- `reviewing`
- `succeeded`
- `failed`
- `blocked`

---

## 7. 狀態流轉規則

實作時至少遵守以下規則：

1. `requires_human_approval = 1` 且 `approval_status != approved` 時，不得進入 `planned`。
2. `planned` 之前不得寫入 `worker_id`、`branch`、`worktree_path`。
3. `dispatched` 之後必須有 `worker_id`。
4. `running` 之後必須有 `started_at`。
5. `reviewing` 只能由 Codex 寫入。
6. `accepted` 只能由 Codex 驗收流程寫入。
7. Hermes 不得直接將任務標記為 `accepted`。
8. quota 或登入失效時，可將任務設為 `blocked`，並同步更新 `worker_state.retry_after` 與 `worker_state.last_error`。

---

## 8. JSON Schema 實作要求

資料庫佈建 agent 不一定要負責 schema 驗證程式，但必須理解以下邊界：

1. Hermes 只驗證 `task envelope` schema。
2. Codex 先讀 envelope，再產生並驗證 `execution manifest`。
3. Dispatcher 只接受 schema 驗證通過的 `execution manifest`。

若資料庫工作同時包含 schema 檔案落地，至少應保存：

- `task-envelope.schema.json`
- `execution-manifest.schema.json`

---

## 9. SQLite Migration Draft

以下 SQL 可直接作為初始 migration 草案：

```sql
BEGIN;

CREATE TABLE IF NOT EXISTS task_envelopes (
  task_id TEXT PRIMARY KEY,
  project TEXT NOT NULL,
  request TEXT NOT NULL,
  source TEXT NOT NULL,
  priority TEXT NOT NULL DEFAULT 'normal',
  requires_human_approval INTEGER NOT NULL DEFAULT 0,
  approval_status TEXT NOT NULL DEFAULT 'not_required',
  approval_note TEXT,
  created_at TEXT NOT NULL,
  created_by TEXT,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS task_executions (
  task_id TEXT PRIMARY KEY,
  project TEXT NOT NULL,
  current_phase TEXT NOT NULL,
  status TEXT NOT NULL,
  base_ref TEXT,
  base_sha TEXT,
  agent TEXT,
  worker_id TEXT,
  branch TEXT,
  worktree_path TEXT,
  prompt_path TEXT,
  execution_manifest_path TEXT,
  result_sha TEXT,
  result_path TEXT,
  fallback_agents_json TEXT,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  lease_owner TEXT,
  lease_expires_at TEXT,
  dispatched_at TEXT,
  started_at TEXT,
  finished_at TEXT,
  last_error TEXT,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (task_id) REFERENCES task_envelopes(task_id)
);

CREATE TABLE IF NOT EXISTS worker_state (
  worker_id TEXT PRIMARY KEY,
  agent TEXT NOT NULL,
  account_pool TEXT,
  enabled INTEGER NOT NULL DEFAULT 1,
  health TEXT NOT NULL DEFAULT 'unknown',
  current_task_id TEXT,
  quota_window TEXT,
  retry_after TEXT,
  last_probe_at TEXT,
  last_error TEXT,
  last_heartbeat_at TEXT,
  updated_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_task_envelopes_approval_status
  ON task_envelopes (approval_status);

CREATE INDEX IF NOT EXISTS idx_task_executions_status_phase
  ON task_executions (status, current_phase);

CREATE INDEX IF NOT EXISTS idx_task_executions_worker_id
  ON task_executions (worker_id);

CREATE INDEX IF NOT EXISTS idx_worker_state_agent_enabled
  ON worker_state (agent, enabled);

CREATE INDEX IF NOT EXISTS idx_worker_state_account_pool_retry_after
  ON worker_state (account_pool, retry_after);

COMMIT;
```

---

## 10. 舊版 `tasks` 單表遷移指引

若現場已存在舊 `tasks` 單表，請依序進行：

1. 先建立 `task_envelopes`、`task_executions`，不要立刻刪除舊表。
2. 將舊 `tasks.created_at` 映射到 `task_envelopes.created_at` 與 `task_executions.updated_at`。
3. 將舊 `tasks.started_at`、`finished_at`、`result_path` 映射到 `task_executions`。
4. 將舊 `tasks.project`、`agent`、`worker_id`、`branch`、`base_sha`、`result_sha` 映射到 `task_executions`。
5. 若無完整原始需求，從舊 task 日誌補寫 `task_envelopes.request`，不可留空。
6. 完成雙寫驗證後，才停用舊 `tasks` 表。

---

## 11. 建議佈建步驟

### 11.1 前置檢查

```bash
sqlite3 --version
test -d /srv/hermes-control/state
test -d /srv/hermes-control/schemas
```

### 11.2 佈建 migration 檔案

將本文件第 9 節 SQL 內容保存到：

```text
/srv/hermes-control/schemas/001_init_sqlite.sql
```

### 11.3 建立資料庫

```bash
sqlite3 /srv/hermes-control/state/coordination.db < /srv/hermes-control/schemas/001_init_sqlite.sql
```

### 11.4 驗證表與索引

```bash
sqlite3 /srv/hermes-control/state/coordination.db ".tables"
sqlite3 /srv/hermes-control/state/coordination.db ".schema task_envelopes"
sqlite3 /srv/hermes-control/state/coordination.db ".schema task_executions"
sqlite3 /srv/hermes-control/state/coordination.db ".schema worker_state"
sqlite3 /srv/hermes-control/state/coordination.db "PRAGMA index_list('task_envelopes');"
sqlite3 /srv/hermes-control/state/coordination.db "PRAGMA index_list('task_executions');"
sqlite3 /srv/hermes-control/state/coordination.db "PRAGMA index_list('worker_state');"
```

### 11.5 驗證可寫入性

建議用一筆 smoke test 測試資料驗證：

```sql
BEGIN;

INSERT INTO task_envelopes (
  task_id, project, request, source, priority,
  requires_human_approval, approval_status, created_at, updated_at
) VALUES (
  'TASK-20260718-001', 'YOUR_REPO', 'smoke test', 'manual', 'normal',
  0, 'not_required', '2026-07-18T10:00:00+08:00', '2026-07-18T10:00:00+08:00'
);

INSERT INTO task_executions (
  task_id, project, current_phase, status, updated_at
) VALUES (
  'TASK-20260718-001', 'YOUR_REPO', 'enveloped', 'queued',
  '2026-07-18T10:00:00+08:00'
);

INSERT INTO worker_state (
  worker_id, agent, enabled, health, updated_at
) VALUES (
  'opencode-01', 'opencode', 1, 'healthy', '2026-07-18T10:00:00+08:00'
);

ROLLBACK;
```

說明：

- 使用 `ROLLBACK`，避免污染正式資料。
- 若外鍵、非空欄位或索引建立有問題，這一步會提早暴露。

---

## 12. agent 完成定義

負責資料庫佈建的 agent，完成工作後必須能交付以下結果：

1. 資料庫檔案已建立。
2. 三張核心表已建立。
3. 五個推薦索引已建立。
4. 表結構與本文件一致。
5. smoke test 可成功插入並 rollback。
6. DB 檔案與 schema 檔案權限合理。
7. 若有舊表，已提出遷移方式或完成遷移驗證。

---

## 13. 不可做的事

1. 不可把 Hermes Memory 當成資料庫替代品。
2. 不可把 secrets、API keys、OAuth token、SSH 私鑰寫入這三張表。
3. 不可把 `worker_state` 當成 task 真相唯一來源。
4. 不可跳過索引建立。
5. 不可只建立表而不做可寫入性驗證。

---

## 14. 後續升級方向

當系統進入以下情況時，再評估升級 PostgreSQL：

1. 多控制節點
2. 高併發派工
3. 需要 row lock / lease 強一致控制
4. 需要更完整的審計與報表

升級時優先保留目前的資料模型與狀態定義，不要同時大改表意與流程。
