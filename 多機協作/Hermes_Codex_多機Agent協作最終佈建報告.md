# Hermes + Codex 多機 Agent 協作最終佈建報告

> 文件版本：1.3  
> 建立日期：2026-07-17  
> 更新日期：2026-07-17  
> 適用情境：使用 Hermes 作為長期控制平面、Codex CLI 作為軟體工程主管，遠端指揮 OpenCode、Claude Code 與 Antigravity CLI。  
> 建議平台：Ubuntu 24.04 LTS，或 Windows 11 + WSL2 Ubuntu。

---

## 1. 執行摘要

本方案採用分層控制：

1. **Hermes：控制平面**
   - 接收使用者指令。
   - 管理排程、重試、通知、記憶與 Worker 健康狀態。
   - 只呼叫固定 Dispatcher，不直接自由拼接 SSH 指令。

2. **Codex CLI：軟體工程主管**
   - 分析需求與 repository。
   - 拆分任務、建立 branch/worktree。
   - 指揮 OpenCode、Claude Code、Antigravity CLI。
   - 驗收 diff、lint、typecheck、test 與安全規則。
   - 預設不得直接合併 `main`。

3. **Worker Agent：執行層**
   - OpenCode：適合明確、可自動化、可輸出 JSON 的程式任務。
   - Claude Code：適合大型重構、跨檔案理解與前後端工作。
   - Antigravity CLI：使用遠端主機已登入 Google 帳號的額度，需額度探測與冷卻管理。

4. **Dispatcher／Worker Wrapper：可靠性邊界**
   - 統一 task manifest、輸出 JSON、逾時、錯誤碼、日誌、額度狀態與 Git 隔離。
   - Hermes 與 Codex 不直接依賴各 CLI 的終端畫面文字。

```text
使用者
  │ Telegram / Web / CLI
  ▼
Hermes Gateway
  ├── 任務 DB、排程、通知、重試
  └── Codex Supervisor
        ├── task manifest / branch / worktree
        ├── Dispatcher
        │     ├── SSH → OpenCode Worker
        │     ├── SSH → Claude Code Worker
        │     └── SSH → Antigravity Worker
        └── diff / lint / test / typecheck / security 驗收
```

---

## 2. 重要原則與限制

- 每台 Worker 使用獨立 repository clone。
- 每個任務使用獨立 branch/worktree。
- 不以 Syncthing、共享磁碟或網路資料夾同步正在修改的工作樹。
- Agent 的文字回覆不是完成證明；Git diff、commit 與測試才是。
- Hermes 或 Codex 不會憑空知道 Antigravity 的 5 小時或 7 天限制。
- 同一 Google 帳號登入多台主機通常仍共享同一 quota pool。
- **Codex CLI 以 ChatGPT 帳號登入使用，不配置 API key。**
- **Claude Code 以 Claude 帳號登入使用，不配置 API key。**
- **Codex CLI 與 Claude Code 仍受各自平台的速率限制與用量限制約束，需由 Wrapper 偵測並退避。**
- CLI 的參數及錯誤格式可能更新，Wrapper 必須保留原始輸出並可版本化測試。
- 正式合併、production 部署、資料庫破壞性 migration 與 secret rotation 必須保留人工核准。

真實來源優先順序：

1. Git commit、branch、diff。
2. CI、lint、typecheck、test。
3. Dispatcher JSON。
4. SQLite/PostgreSQL 任務狀態。
5. Hermes 記憶僅作輔助。

---

## 3. 主機角色

| 主機 | 名稱 | 用途 | 必裝元件 |
|---|---|---|---|
| A | `ctrl-hermes` | Gateway、DB、排程、通知 | Hermes、Git、SSH client、Tailscale、SQLite/PostgreSQL client |
| B | `ctrl-codex` | 工程規劃與驗收 | Codex CLI、ChatGPT 帳號登入、Git、GitHub CLI、專案工具鏈、Tailscale |
| C | `worker-opencode` | OpenCode 任務 | OpenCode、Git、專案工具鏈、SSH server、Tailscale |
| D | `worker-claude` | Claude Code 任務 | Claude Code、Claude 帳號登入、Git、專案工具鏈、SSH server、Tailscale |
| E | `worker-antigravity` | Antigravity 任務 | Antigravity CLI、Google 帳號登入、Git、專案工具鏈、SSH server、Tailscale |

小型部署可將 A、B 合併，但正式環境建議邏輯隔離。

---

## 4. 作業系統與網路

### 4.1 Ubuntu 基本套件

```bash
sudo apt update
sudo apt install -y \
  git curl wget jq openssh-client openssh-server \
  ca-certificates build-essential sqlite3 rsync tmux unzip xz-utils
sudo systemctl enable --now ssh
```

Windows 建議使用 WSL2：

```powershell
wsl --install -d Ubuntu-24.04
```

### 4.2 Tailscale

每台主機：

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

設定主機名稱：

- `ctrl-hermes`
- `ctrl-codex`
- `worker-opencode`
- `worker-claude`
- `worker-antigravity`

確認：

```bash
tailscale status
ping -c 3 worker-opencode
```

### 4.3 防火牆

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow in on tailscale0 to any port 22 proto tcp
sudo ufw enable
```

不要將 OpenCode server 或 SSH 直接暴露在公網。

---

## 5. Worker 帳號與 SSH

每台 Worker 建立低權限帳號：

```bash
sudo adduser agentworker
```

控制節點建立專用金鑰：

```bash
ssh-keygen -t ed25519 -a 100 -f ~/.ssh/id_ed25519_agentfleet
ssh-copy-id -i ~/.ssh/id_ed25519_agentfleet.pub agentworker@worker-opencode
ssh-copy-id -i ~/.ssh/id_ed25519_agentfleet.pub agentworker@worker-claude
ssh-copy-id -i ~/.ssh/id_ed25519_agentfleet.pub agentworker@worker-antigravity
```

`~/.ssh/config`：

```sshconfig
Host worker-opencode worker-claude worker-antigravity
  User agentworker
  IdentityFile ~/.ssh/id_ed25519_agentfleet
  IdentitiesOnly yes
  BatchMode yes
  ConnectTimeout 10
  ServerAliveInterval 20
  ServerAliveCountMax 3
```

SSH Server 強化：

```text
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
X11Forwarding no
AllowAgentForwarding no
AllowUsers agentworker
```

Worker 不應具有無限制免密碼 sudo。

---

## 6. Git 配置

每台 Worker：

```bash
sudo mkdir -p /srv/agent/{repos,worktrees,logs,tasks,results}
sudo chown -R agentworker:agentworker /srv/agent
sudo -iu agentworker
git clone git@github.com:YOUR_ORG/YOUR_REPO.git /srv/agent/repos/YOUR_REPO
```

Branch 命名：

```text
agent/<agent-name>/<task-id>
```

建立 worktree：

```bash
REPO=/srv/agent/repos/YOUR_REPO
TASK_ID=TASK-20260717-001
BRANCH=agent/opencode/$TASK_ID
WORKTREE=/srv/agent/worktrees/$TASK_ID

git -C "$REPO" fetch origin
git -C "$REPO" worktree add -b "$BRANCH" "$WORKTREE" origin/main
```

GitHub 必須設定 branch protection，Worker 不可直接 push `main`。

---

## 7. Hermes 控制平面

### 7.1 安裝

```bash
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
source ~/.bashrc
hermes setup --portal
```

建議 Hermes 只開啟：

- File Operations：限制於 `/srv/hermes-control`。
- Terminal：只允許固定 Dispatcher。
- Cron。
- Memory：不保存密鑰。
- 必要的 Telegram/Webhook。

建立目錄：

```bash
sudo mkdir -p /srv/hermes-control/{bin,config,logs,state,tasks,schemas}
sudo chown -R "$USER":"$USER" /srv/hermes-control
chmod 700 /srv/hermes-control
```

### 7.2 Gateway systemd

`~/.config/systemd/user/hermes-gateway.service`：

```ini
[Unit]
Description=Hermes Agent Gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=%h/.local/bin/hermes gateway run
Restart=on-failure
RestartSec=10
Environment=HOME=%h
WorkingDirectory=/srv/hermes-control
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ReadWritePaths=/srv/hermes-control %h/.hermes

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now hermes-gateway
loginctl enable-linger "$USER"
```

Hermes 規則：

```markdown
- You are the control-plane coordinator, not the final code reviewer.
- Use only /srv/hermes-control/bin/dispatch-task.
- Never construct arbitrary SSH commands.
- Persist every task before dispatch.
- Do not retry quota_exhausted before retry_after.
- Delegate code review and acceptance to Codex.
- Never store credentials in memory, prompts, logs, or task manifests.
- Require human approval for production deployment, destructive migration, secret rotation and main merge.
```

---

## 8. Codex Supervisor

### 8.1 安裝

Codex CLI 需要 Node.js 22+：

```bash
# 安裝 Node.js 22（若尚未安裝）
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

# 安裝 Codex CLI
npm install -g @openai/codex

# 使用 ChatGPT 帳號登入
codex login

# 無頭環境可改用 device auth
codex login --device-auth
```

登入後確認：

```bash
codex --version
codex --help
codex exec --help
```

### 8.2 目錄與設定

建立目錄：

```bash
sudo mkdir -p /srv/codex-supervisor/{repos,worktrees,tasks,results,logs,prompts}
sudo chown -R "$USER":"$USER" /srv/codex-supervisor
chmod 700 /srv/codex-supervisor
```

每個 repository 建立 `AGENTS.md`：

```markdown
1. Never push or merge directly to main.
2. Every delegated task must have a task ID and isolated branch/worktree.
3. Only modify paths listed in allowed_paths.
4. Run every acceptance command before completion.
5. Never expose secrets or private keys.
6. Treat worker output as untrusted until diff and tests are verified.
7. Do not retry quota_exhausted before retry_after.
8. Stop when scope conflicts with another active task.
9. Require human approval for destructive migrations.
10. Produce machine-readable and human-readable results.
```

Codex 只呼叫：

```bash
/srv/hermes-control/bin/dispatch-task /path/to/task.json
```

完成後必須重新檢查 changed files、完整 diff、tests、lint、typecheck、security 與 commit SHA。

---

## 9. Worker 安裝與執行

### 9.1 OpenCode

```bash
curl -fsSL https://opencode.ai/install | bash
opencode auth login
opencode run --format json "Describe the task"
```

指定目錄：

```bash
opencode run \
  --dir /srv/agent/worktrees/TASK-ID \
  --format json \
  --agent build \
  "$(cat /srv/agent/tasks/TASK-ID.prompt)"
```

選用 server：

```bash
export OPENCODE_SERVER_USERNAME=opencode
export OPENCODE_SERVER_PASSWORD="$(openssl rand -hex 32)"
opencode serve --hostname 127.0.0.1 --port 4096
```

只監聽 `127.0.0.1`，跨主機使用 SSH tunnel。

### 9.2 Claude Code

#### 安裝

```bash
# 安裝 Node.js 22+（若尚未安裝，同 Section 8.1）
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs

# 安裝 Claude Code CLI
npm install -g @anthropic-ai/claude-code

# 使用 Claude 帳號登入（互動式，完成後憑證保留於本機）
claude login
```

依官方文件安裝及登入後確認：

```bash
claude --version
claude --help
claude -p "Return OK only"
```

#### 執行任務

```bash
cd /srv/agent/worktrees/TASK-ID
claude -p "$(cat /srv/agent/tasks/TASK-ID.prompt)" --output-format json
```

不要預設永久使用完全跳過權限檢查；權限應由 Wrapper、檔案路徑、OS 帳號與 sandbox 共同限制。

### 9.3 Antigravity CLI

#### 安裝

```bash
# 安裝 Antigravity CLI（以官方安裝腳本為準，正式部署前請核對 agy --help）
curl -fsSL https://antigravity.google/install.sh | bash
source ~/.bashrc

# 確認安裝
agy --version
agy --help
```

#### Google 帳號登入

在 Worker 本機完成 Google 帳號登入，憑證保留於該機器：

```bash
agy auth login
# 依照互動提示完成 Google OAuth 瀏覽器授權
```

確認登入狀態與額度：

```bash
agy auth status
```

在互動 CLI 中使用：

```text
/quota
```

Codex/Hermes 不搬移登入 token，而是透過 SSH 到已登入主機執行 CLI。具體非互動參數必須以該版本 `agy --help` 為準。

---

## 10. Task Manifest

```json
{
  "task_id": "TASK-20260717-001",
  "project": "YOUR_REPO",
  "base_ref": "origin/main",
  "agent": "opencode",
  "worker_id": "opencode-01",
  "prompt": "新增訂單查詢 API 並補測試",
  "allowed_paths": ["src/orders", "tests/orders"],
  "denied_paths": [".git", ".github/workflows", ".env", "secrets"],
  "acceptance_commands": ["npm run lint", "npm run typecheck", "npm test"],
  "timeout_seconds": 3600,
  "must_commit": true,
  "fallback_agents": ["claude", "codex"]
}
```

Dispatcher 必須驗證 schema、project allowlist、agent allowlist、path、命令及 timeout。

---

## 11. 統一結果 JSON 與 Exit Code

```json
{
  "task_id": "TASK-20260717-001",
  "agent": "antigravity",
  "worker_id": "antigravity-01",
  "status": "quota_exhausted",
  "reason": {
    "category": "usage_limit",
    "window": "five_hour",
    "retry_after": "2026-07-17T20:00:00+08:00",
    "raw_message_file": "logs/TASK-ID/worker.stderr"
  },
  "execution": {
    "started": false,
    "exit_code": 73,
    "duration_seconds": 3
  },
  "fallback_recommended": true
}
```

自訂 Exit Code：

| Code | 意義 |
|---:|---|
| 0 | 任務完成 |
| 70 | Agent 執行錯誤 |
| 71 | 登入失效 |
| 72 | 權限確認或互動阻塞 |
| 73 | 5 小時額度限制（Antigravity） |
| 74 | 7 天／weekly 限制（Antigravity） |
| 75 | 額度限制但窗口未知 |
| 76 | 網路錯誤 |
| 77 | 任務逾時 |
| 78 | 修改範圍越界 |
| 79 | 驗收失敗 |
| 80 | Codex CLI 速率限制或帳號配額限制（短期） |
| 81 | Codex CLI 帳號配額或日用量上限 |
| 82 | Codex CLI 帳號登入失效 |
| 83 | Claude Code 速率限制（短期 429） |
| 84 | Claude Code 每日／月用量上限 |
| 85 | Claude Code 帳號登入失效或 OAuth token 過期 |

這些為本系統協定，不是各 CLI 官方 exit code。

---

## 12. Antigravity 額度偵測

Codex 不直接管理 quota，只讀 Worker 回傳狀態。

Wrapper 流程：

```text
讀取 worker cooldown
  ├─ 尚未到 retry_after → 直接回 quota_exhausted
  └─ 可探測
       ├─ auth probe
       ├─ /quota 或低成本 probe
       ├─ 執行正式任務
       ├─ 分析 exit code/stdout/stderr
       └─ 更新 worker_state 並回傳 JSON
```

辨識順序：

1. 優先讀官方回傳的限制名稱。
2. 解析 `retry_after` 或 reset time。
3. 明確出現 weekly／7 day → `weekly`。
4. 明確出現 5 hour → `five_hour`。
5. 不明確時 → `unknown`，保留原始訊息。

重試策略：

- 5 小時限制：到 `retry_after` 後只 probe 一次。
- weekly：沒有明確 reset time 時，每日最多 probe 一次或人工解除。
- unknown quota：預設冷卻 5 小時後 probe 一次。
- 登入失效：停用 Worker 並通知人工。
- 同一帳號的所有 Worker 應共用 quota 狀態。

不要依最近使用時間自行猜測額度；實際錯誤與 `/quota` 才是依據。

---

## 12b. Codex CLI 速率與用量限制偵測

Codex CLI 以 ChatGPT 帳號登入使用，仍受平台速率限制、帳號配額與訂閱方案用量限制約束。

### 限制類型辨識

| 錯誤訊號／訊息特徵 | 分類 | Exit Code |
|---|---|---|
| `rate_limit_exceeded`、`too many requests`、`requests per minute` | 短期速率限制 | 80 |
| `quota exceeded`、`usage limit`、`daily limit` | 帳號配額或日用量上限 | 81 |
| `login required`、`auth expired`、`unauthorized` | 帳號登入失效 | 82 |

### Wrapper 偵測流程

```text
執行 codex exec / codex run
  ├─ exit 0 → 正常完成
  ├─ stderr 含速率限制關鍵字
  │     → exit 80，寫入 retry_after（若有 Retry-After 則採用，否則預設 60s）
  ├─ stderr 含 quota / usage / daily limit 關鍵字
  │     → exit 81，寫入 retry_after（依官方訊息或預設 24h）
  ├─ stderr 含 login required / auth expired / unauthorized
  │     → exit 82，停用 Worker，通知人工重新登入
  └─ 其他非零 → exit 70
```

### 重試策略

- **exit 80**：指數退避，最小 60 秒，最大 10 分鐘；減少同一帳號的並行任務數量。
- **exit 81**：停止向該帳號派工直到 reset；有 fallback agent 時立即切換。
- **exit 82**：停用 Worker、發出人工通知，不自動重試。
- **帳號共享**：同一 ChatGPT 帳號使用於多台 Worker 時，quota 狀態應共用。

### 探測方式

Codex CLI 沒有專屬 `/quota` 指令。Wrapper 可在正式任務前發送最小化 probe（如單行 `echo` 任務），以低成本確認登入狀態仍有效且未觸發速率限制。

---

## 12c. Claude Code 速率與用量限制偵測

Claude Code 以 Claude 帳號登入使用，受 RPM、tokens per minute、每日請求上限及 Max plan 月用量約束。

### 限制類型辨識

| HTTP 狀態 | 錯誤碼／訊息特徵 | 分類 | Exit Code |
|---|---|---|---|
| 429 | `rate_limit_error`、`overloaded_error`、`requests per minute` | 短期速率限制 | 83 |
| 429 / 529 | `usage_limit_reached`、`monthly limit`、`daily limit` | 每日／月用量上限 | 84 |
| 401 | `authentication_error`、`login required`、OAuth token expired | 帳號登入失效 | 85 |

### Wrapper 偵測流程

```text
執行 claude -p ... --output-format json
  ├─ exit 0 + 有效 JSON → 正常完成
  ├─ stderr/JSON error 含 rate_limit / overloaded + 短期特徵
  │     → exit 83，寫入 retry_after（Retry-After header 或預設 60s）
  ├─ stderr/JSON error 含 usage_limit / monthly / daily
  │     → exit 84，寫入 retry_after（隔日或月底，或人工解除）
  ├─ stderr/JSON error 含 authentication_error / login required / OAuth expired
  │     → exit 85，停用 Worker，通知人工
  └─ 其他非零 → exit 70
```

### 重試策略

- **exit 83（短期速率）**：指數退避，最小 60 秒，最大 15 分鐘；減少同一帳號的並行任務數量。
- **exit 84（每日／月上限）**：
  - 有明確 reset time → 寫入 `retry_after`，停止派工。
  - 無明確 reset time → 預設冷卻 24 小時後 probe 一次。
  - 有 fallback agent 時立即切換（如 Codex CLI 或 OpenCode）。
- **exit 85（登入失效）**：停用 Worker、發出人工通知；OAuth token 過期時引導人工重新登入，不自動嘗試刷新 token。
- **帳號隔離**：Max plan 用量綁定 Claude 帳號，同帳號多台 Worker 共用同一 quota pool，狀態應集中記錄。

### 探測方式

使用最小化 probe 任務確認可用性：

```bash
claude -p "Reply with OK only." --output-format json
```

解析回傳 JSON：有效 `content` 欄位代表可用；出現 `error` 欄位則依上述規則分類。

---

## 13. Dispatcher 設計

`workers.yaml`：

```yaml
workers:
  opencode-01:
    agent: opencode
    host: worker-opencode
    wrapper: /srv/agent/bin/run-opencode
    max_parallel: 2
  claude-01:
    agent: claude
    host: worker-claude
    wrapper: /srv/agent/bin/run-claude
    max_parallel: 1
  antigravity-01:
    agent: antigravity
    host: worker-antigravity
    wrapper: /srv/agent/bin/run-antigravity
    max_parallel: 1
```

Dispatcher 必須：

1. 驗證 task schema。
2. 查詢 Worker 狀態與 cooldown。
3. 建立獨立 branch/worktree。
4. 將 task 透過 stdin 或受控檔案傳送。
5. 使用 `timeout`/cgroup 限制執行時間。
6. 收集 stdout/stderr。
7. 驗證結果 JSON。
8. 檢查 changed paths。
9. 執行 acceptance commands。
10. 保存 commit、patch、結果與日誌。

禁止把未過濾的 prompt 直接嵌入 SSH shell 字串；優先使用 stdin 或 base64 task payload。

---

## 14. 狀態資料庫

SQLite MVP：

```sql
CREATE TABLE worker_state (
  worker_id TEXT PRIMARY KEY,
  agent TEXT NOT NULL,
  account_pool TEXT,
  enabled INTEGER NOT NULL DEFAULT 1,
  health TEXT NOT NULL DEFAULT 'unknown',
  quota_window TEXT,
  retry_after TEXT,
  last_probe_at TEXT,
  last_error TEXT,
  updated_at TEXT NOT NULL
);

CREATE TABLE tasks (
  task_id TEXT PRIMARY KEY,
  project TEXT NOT NULL,
  agent TEXT,
  worker_id TEXT,
  status TEXT NOT NULL,
  branch TEXT,
  base_sha TEXT,
  result_sha TEXT,
  created_at TEXT NOT NULL,
  started_at TEXT,
  finished_at TEXT,
  result_path TEXT
);
```

多控制節點或高並行時改用 PostgreSQL，並加入 row lock／lease。

---

## 15. Codex 驗收

Worker 回傳 `completed` 後，Codex 必須：

1. 確認 task manifest 與 base commit。
2. 檢查 changed files 是否超出 `allowed_paths`。
3. 掃描秘密、危險 workflow、未知 binary 與 dependency 變更。
4. 閱讀完整 diff。
5. 執行所有 acceptance commands。
6. 執行必要回歸與安全測試。
7. 檢查 API contract 與 migration。
8. 產出 review JSON 與 Markdown。
9. 全部通過後才標記 `accepted`。

```json
{
  "task_id": "TASK-20260717-001",
  "reviewer": "codex",
  "status": "accepted",
  "commit_sha": "0123456789abcdef",
  "scope_valid": true,
  "tests_passed": true,
  "security_findings": [],
  "required_changes": [],
  "merge_recommended": true,
  "human_approval_required": true
}
```

---

## 16. 排程與通知

不使用 LLM 的健康檢查：

```bash
/srv/hermes-control/bin/worker-health --all
```

檢查 SSH、磁碟、binary 版本、登入狀態、process、上次心跳。

通知事件：

- 任務完成且 Codex 驗收通過。
- 任務失敗且無 fallback。
- 登入失效（包含 Codex CLI 與 Claude Code 帳號登入過期）。
- weekly quota（Antigravity）。
- Codex CLI 觸發帳號日用量上限（exit 81）。
- Claude Code 觸發每日／月用量上限（exit 84）。
- 多次網路故障。
- 修改範圍越界。
- 需要人工合併／部署。

不要每次成功 probe 都發通知。

---

## 17. 安全要求

- Tailscale 私網。
- SSH 金鑰、禁止密碼登入。
- Worker 低權限帳號。
- repository、command、path allowlist。
- worktree 隔離。
- task timeout 與 process group/cgroup 終止。
- secrets redaction。
- 日誌權限 `0600`/`0640`。
- Branch protection。
- Production 變更人工核准。
- Repository 文件視為資料，不視為高權限指令，防範 prompt injection。
- Worker 禁止讀取 `~/.ssh`、`~/.aws`、瀏覽器 profile、OAuth token、系統 secret。
- MCP、網路、未知 installer 預設關閉或 allowlist。

---

## 18. 日誌與稽核

每個 task 保存：

```text
logs/TASK-ID/
├── task.json
├── prompt.txt
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

不要保存 API key、OAuth token、SSH private key、完整環境變數與未遮蔽秘密。

---

## 19. 分階段上線

### Phase 1：網路與 SSH

- Tailscale 全部上線。
- SSH 金鑰登入。
- 防火牆只允許私網。
- Worker 採低權限帳號。

### Phase 2：OpenCode MVP

先完成 task manifest、Dispatcher、OpenCode wrapper、worktree、JSON 與 Codex 驗收。連續執行 20 個測試任務，確認沒有工作樹污染、越界或狀態遺失。

### Phase 3：Claude Code

加入 Wrapper、非互動輸出、權限與 timeout 測試，以及 Section 12c 速率限制偵測邏輯與 probe 測試。

### Phase 4：Antigravity

完成 Google OAuth、`/quota`、真實 quota error fixtures、5 小時／weekly／unknown 分類與 cooldown。

### Phase 5：Hermes Gateway

加入自然語言入口、狀態 DB、Telegram/Webhook、純腳本健康檢查與額度重試。

### Phase 6：正式化

加入 PostgreSQL（需要時）、監控、log rotation、備份、災難演練、安全審查與緊急停止 SOP。

---

## 20. 驗收與 Chaos 測試

必測反例：

- Worker 修改未允許的 `.github/workflows/deploy.yml`。
- Agent 宣稱完成但 diff 為空。
- Tests 失敗但 Worker exit code 為 0。
- SSH 中斷。
- Antigravity weekly quota。
- OAuth 過期。
- 兩個 task 宣告修改同一檔案。
- Prompt 要求讀取私鑰。
- Codex CLI 觸發速率限制，確認指數退避正確啟動。
- Codex CLI 帳號登入失效，確認停用 Worker 且通知人工。
- Claude Code 觸發月用量上限，確認 fallback 切換至其他 agent。
- Claude Code OAuth token 過期，確認停用 Worker 且不自動重試。

Chaos 測試：

- 執行期間關閉 Worker。
- 磁碟空間不足。
- Git remote 暫時失效。
- Agent process 不退出。
- stdout 超大。
- CLI 更新導致錯誤格式改變。
- `retry_after` 時區解析錯誤。
- Codex CLI 與 Claude Code 同時觸發速率限制，確認 Hermes fallback 排隊邏輯正確。

---

## 21. 日常 SOP

新任務：

1. 使用者向 Hermes 提交目標。
2. Hermes 建立 task manifest。
3. 高風險任務先人工核准。
4. Codex 檢查與拆分。
5. Dispatcher 選擇 Worker。
6. Worker 執行。
7. Codex 驗收。
8. Hermes 通知。
9. 人工決定 PR、合併與部署。

額度用盡（適用所有 Agent）：

1. Wrapper 回傳 `quota_exhausted`（exit 73–75、80–85）。
2. 寫入 `retry_after` 與 `quota_window`。
3. Hermes 停止向該 Worker / quota pool 派工。
4. 有 fallback agent 時立即改派，否則排隊。
5. 到期後只 probe 一次，確認可用再恢復。
6. 恢復後更新 Worker 為 healthy。
7. 認證失效（exit 71、82、85）：不自動重試，通知人工處理。

緊急停止：

```bash
systemctl --user stop hermes-gateway
```

終止 Agent 時應使用 task-specific PID/cgroup，避免誤殺其他任務。

---

## 22. 最終建議

```text
Hermes = 控制平面
Codex = 工程主管與最終驗收
OpenCode / Claude Code / Antigravity = 執行 Worker
Dispatcher + JSON + Git + DB = 可靠性核心
```

最重要的五項原則：

1. **模型負責判斷，程式負責約束。**
2. **Agent 的文字回覆不是完成證明，Git 與測試才是。**
3. **額度偵測在 Worker（含 Codex CLI、Claude Code、Antigravity），調度決策在 Hermes。**
4. **工程驗收在 Codex，不在 Hermes。**
5. **正式合併與 production 部署保留人工核准。**

---

## 23. 官方參考來源

- Hermes Agent Documentation: https://hermes-agent.nousresearch.com/docs/
- Hermes Configuration: https://hermes-agent.nousresearch.com/docs/user-guide/configuration/
- Hermes Scheduled Tasks: https://hermes-agent.nousresearch.com/docs/user-guide/features/cron/
- Hermes Messaging: https://hermes-agent.nousresearch.com/docs/user-guide/messaging/
- OpenAI Codex Documentation: https://developers.openai.com/codex/
- OpenAI Rate Limits: https://platform.openai.com/docs/guides/rate-limits
- OpenCode CLI: https://opencode.ai/docs/cli/
- OpenCode Server: https://opencode.ai/docs/server/
- Claude Code Documentation: https://docs.anthropic.com/en/docs/claude-code/
- Anthropic Rate Limits: https://docs.anthropic.com/en/api/rate-limits
- Google Antigravity CLI Overview: https://antigravity.google/docs/cli-overview
- Google Antigravity CLI Reference: https://antigravity.google/docs/cli-reference
- Google Antigravity Plans: https://antigravity.google/docs/plans

> CLI 與方案更新快速，正式部署前應重新核對各工具目前版本的 `--help`、登入方式、額度政策與官方安全文件。
