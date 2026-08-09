# Hermes 自主佈建與執行規格

> 適用範圍：`Twitch下載/` 獨立專案。  
> 決策狀態：已建立自主佈建與執行規格。  
> 目的：讓 Hermes 在 PI16G001 上能依文件完成 preflight、套件安裝、目錄建立、runner 產生、每日任務建立、Twitch VOD 下載、結果回報與錯誤通知。  
> 建立日期：2026-08-09

---

## 1. 結論

本文件補上 Hermes 從「需求規格」走到「可自主執行」所需的作業流程。

Hermes 若要自主完成 Twitch 下載作業，必須同時讀取本目錄內所有必讀文件，並依本文件產生或確認實機上的 runner、目錄、套件與任務產物。

本文件允許 Hermes 在 PI16G001 上做以下事情：

1. 執行 preflight 檢查。
2. 建立本專案需要的目錄。
3. 安裝 allowlist 內的必要套件。
4. 安裝或更新 `yt-dlp`。
5. 確認 `ffmpeg` 可用。
6. 產生 `/srv/twitch-worker/bin/run-twitch-archive` runner。
7. 依 manifest 下載 Twitch VOD。
8. 產生 `result.json`、`download-report.json` 與相關任務產物。
9. 透過 Hermes 既有 Discord 綁定發送必要通知。

本文件不允許 Hermes：

1. 安裝 allowlist 以外的套件。
2. 保存或寫入 Discord webhook、bot token、Twitch OAuth token、cookie、密碼或其他 secret。
3. 自行變更下載來源、畫質、存放路徑、保留策略、聊天紀錄策略或通知策略。
4. 自動刪除已下載影片。
5. 將本專案與其他根目錄的 Hermes 設計混用。

---

## 2. 前置必讀文件

Hermes 在任何 bootstrap、deploy、run、repair 或 retry 動作前，必須先讀取：

1. `Twitch下載/README.md`
2. `Twitch下載/PI16G001_Hermes_Twitch歸檔Worker設定.md`
3. `Twitch下載/聊天紀錄保存策略.md`
4. `Twitch下載/影片保留策略.md`
5. `Twitch下載/下載畫質設定.md`
6. `Twitch下載/Hermes自主佈建與執行規格.md`

若任一必讀文件缺失、不可讀或互相衝突，Hermes 必須停止自主執行，回報 `blocked_document_conflict_or_missing_required_doc`。

---

## 3. 自主佈建變數

```yaml
HERMES_TWITCH_AUTONOMOUS_BOOTSTRAP:
  # 是否允許 Hermes 依本文件自主執行 bootstrap。
  enabled: true

  # 目標節點。
  # 來源：使用者提供的實機資訊。
  target_worker_id: "PI16G001"
  target_hostname: "PI16G001"
  target_os: "Debian GNU/Linux 13 trixie"
  target_architecture: "aarch64"

  # 是否允許安裝 allowlist 內套件。
  # 注意：若 runtime 沒有 sudo 或套件管理權限，Hermes 必須回報 blocked_missing_privilege。
  package_install_allowed: true

  # 套件安裝權限來源。
  # 用途：提醒 Hermes 安裝需在 PI16G001 上執行，不是在 GitHub repo 或對話環境執行。
  package_install_context: "PI16G001_runtime_only"

  # 允許安裝的 apt 套件清單。
  # Hermes 不得安裝此清單以外的 apt 套件，除非使用者更新本文件。
  apt_package_allowlist:
    - "ca-certificates"
    - "curl"
    - "ffmpeg"
    - "jq"
    - "python3"
    - "python3-venv"
    - "pipx"

  # 允許透過 pipx 安裝的 Python CLI 工具。
  # yt-dlp 用於實際下載 Twitch VOD。
  pipx_package_allowlist:
    - "yt-dlp"

  # 禁止安裝的類型。
  # 用途：避免 Hermes 擅自擴大系統變更範圍。
  install_denied_categories:
    - "global npm packages"
    - "system-wide custom binaries outside allowlist"
    - "Docker images not specified by this project"
    - "packages requiring secret credentials"
    - "unreviewed third-party install scripts"

  # 本專案允許建立的目錄。
  managed_directories:
    - "/srv/hermes-twitch"
    - "/srv/hermes-twitch/tasks"
    - "/srv/hermes-twitch/state"
    - "/srv/twitch-worker"
    - "/srv/twitch-worker/bin"
    - "/srv/twitch-worker/results"
    - "/var/lib/twitch-archiver"
    - "/var/log/twitch-archiver"
    - "/tmp/twitch-archive-work"

  # 主要影片輸出根目錄。
  # 實際值仍以 PI16G001_Hermes_Twitch歸檔Worker設定.md 的 storage.STORAGE_PATH_VARIABLES 為準。
  output_root_primary: "/mnt/twitch-archive"

  # fallback 影片輸出根目錄。
  # 實際值仍以主設定檔為準。
  output_root_fallback: "/srv/twitch-archive"

  # runner 固定路徑。
  runner_path: "/srv/twitch-worker/bin/run-twitch-archive"

  # 是否允許產生 runner。
  runner_generation_allowed: true

  # 是否允許修改既有 runner。
  # 行為：允許，但必須先備份舊 runner，並在 report 中記錄變更。
  runner_update_allowed: true

  # runner 備份目錄。
  runner_backup_dir: "/srv/twitch-worker/backups"

  # 通知管道。
  # 來源：使用者已確認 Hermes 本身有綁定 Discord 頻道。
  notification_channel: "discord_via_hermes_existing_binding"

  # 禁止保存 secrets。
  # 行為：任何 webhook、token、cookie、password 不得寫入 repo、manifest、log 或 report。
  secrets_in_repository_allowed: false
```

---

## 4. Preflight 檢查

Hermes 在安裝或執行下載前，必須先執行 preflight。

### 4.1 必查項目

```yaml
PREFLIGHT_CHECKS:
  host_identity:
    required_hostname: "PI16G001"
    on_mismatch: "blocked_wrong_host"

  os:
    required_family: "Debian"
    expected_version: "13"
    on_mismatch: "blocked_os_mismatch"

  architecture:
    required: "aarch64"
    on_mismatch: "blocked_architecture_mismatch"

  disk:
    check_output_root: true
    min_free_space_gb: 1
    on_below_minimum: "notify_discord_and_block_task"

  network:
    require_dns: true
    require_https: true
    require_twitch_access: true
    on_failure: "blocked_network_unavailable"

  privileges:
    require_sudo_for_bootstrap: true
    on_missing_sudo: "blocked_missing_privilege"

  required_docs:
    require_all_agent_docs: true
    on_missing_doc: "blocked_missing_required_doc"
```

### 4.2 Preflight 產物

Preflight 必須在 task 目錄產生：

```text
preflight-result.json
preflight-report.md
```

`preflight-result.json` 至少包含：

```json
{
  "worker_id": "PI16G001",
  "hostname_ok": true,
  "os_ok": true,
  "architecture_ok": true,
  "disk_ok": true,
  "network_ok": true,
  "privilege_ok": true,
  "required_docs_ok": true,
  "status": "passed"
}
```

若任一項不通過，`status` 必須為 `blocked`，並寫入 `blocked_reason`。

---

## 5. 套件安裝規格

### 5.1 安裝原則

Hermes 安裝套件必須符合：

1. 只能在 PI16G001 runtime 上執行。
2. 只能安裝 allowlist 內套件。
3. 安裝前必須檢查是否已存在，避免重複或破壞性操作。
4. 安裝失敗必須停止 bootstrap，寫入 report，並通知使用者。
5. 不得使用未審核的第三方 shell install script。

### 5.2 apt 套件 allowlist

允許安裝：

```text
ca-certificates
curl
ffmpeg
jq
python3
python3-venv
pipx
```

### 5.3 pipx 工具 allowlist

允許安裝：

```text
yt-dlp
```

### 5.4 安裝命令模板

Hermes 可依實機狀態執行等價命令：

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl ffmpeg jq python3 python3-venv pipx
python3 -m pipx ensurepath
pipx install yt-dlp || pipx upgrade yt-dlp
```

若 `yt-dlp` 已存在，Hermes 應優先執行版本檢查與 `pipx upgrade yt-dlp`，而不是重複安裝。

### 5.5 安裝驗證

安裝後必須驗證：

```bash
ffmpeg -version
yt-dlp --version
python3 --version
jq --version
```

驗證結果必須寫入：

```text
bootstrap-report.json
bootstrap-report.md
```

---

## 6. 目錄與權限規格

Hermes 必須建立或確認以下目錄：

```text
/srv/hermes-twitch
/srv/hermes-twitch/tasks
/srv/hermes-twitch/state
/srv/twitch-worker
/srv/twitch-worker/bin
/srv/twitch-worker/results
/srv/twitch-worker/backups
/var/lib/twitch-archiver
/var/log/twitch-archiver
/tmp/twitch-archive-work
```

影片輸出目錄依主設定檔決定：

```text
/mnt/twitch-archive
/srv/twitch-archive
```

若 `/mnt/twitch-archive` 不存在、未掛載或不可寫，且 fallback 可用，Hermes 可依主設定檔改用 `/srv/twitch-archive`；但必須在 `result.json` 與 `download-report.json` 記錄實際使用路徑。

若 primary 與 fallback 都不可用，任務狀態必須為：

```text
blocked_output_root_unavailable
```

---

## 7. Runner 產生規格

### 7.1 Runner 路徑

Hermes 必須產生或確認：

```text
/srv/twitch-worker/bin/run-twitch-archive
```

### 7.2 Runner 責任

runner 只負責執行，不負責自行決策。

runner 必須：

1. 接收 `execution-manifest.json` 路徑作為輸入。
2. 從 manifest 讀取 Twitch 來源、輸出路徑、畫質策略、聊天紀錄策略、保留策略與通知策略。
3. 檢查磁碟空間。
4. 產生 yt-dlp URL 清單。
5. 呼叫 yt-dlp 下載符合策略的 VOD。
6. 寫出任務產物。
7. 遇到需通知情況時，呼叫 Hermes 既有通知介面。
8. 不得自行硬編碼 Twitch 來源、輸出路徑、畫質或通知管道。

### 7.3 Runner 不得做的事

runner 不得：

1. 自行下載 Twitch chat。
2. 自行刪除已下載影片。
3. 自行降到 480p 或更低畫質。
4. 自行保存 Discord webhook、bot token、Twitch token 或 cookie。
5. 自行修改 repo 文件。
6. 自行改變每日排程。

---

## 8. execution-manifest.json 規格

Hermes 每次建立每日任務時，必須將所有已確認策略轉成 `execution-manifest.json`。

manifest 至少包含：

```json
{
  "project": "twitch-archive",
  "context_root": "Twitch下載",
  "task_profile": "twitch_daily_vod_archive",
  "worker_id": "PI16G001",
  "runner_path": "/srv/twitch-worker/bin/run-twitch-archive",
  "timezone": "Asia/Taipei",
  "schedule_recurrence": "daily",
  "video_quality_mode": "1080p",
  "target_height": 1080,
  "fallback_quality_mode": "720p",
  "fallback_height": 720,
  "if_1080p_unavailable": "fallback_to_720p",
  "if_1080p_and_720p_unavailable": "notify_user_and_end_daily_job",
  "allow_below_720p_fallback": false,
  "chat_archive_enabled": false,
  "video_retention_mode": "keep_forever_until_user_deletes",
  "auto_delete_videos": false,
  "low_disk_space_threshold_gb": 1,
  "low_disk_space_action": "notify_user_via_discord_and_block_task",
  "notification_channel": "discord_via_hermes_existing_binding"
}
```

若 `TWITCH_CHANNEL_SOURCES` 為空，Hermes 不得建立實際下載任務，必須回報：

```text
requires_user_input_channel_sources_empty
```

---

## 9. yt-dlp 執行規格

runner 必須依 manifest 組合 yt-dlp 命令。

畫質 selector 由 `下載畫質設定.md` 提供，目前為：

```text
bestvideo[height=1080]+bestaudio/best[height=1080]/bestvideo[height=720]+bestaudio/best[height=720]
```

runner 必須使用：

```text
--download-archive
--ignore-errors
--no-overwrites
--continue
--write-info-json
--write-thumbnail
--merge-output-format mp4
```

runner 不得加入任何 chat 下載參數。

若 yt-dlp 偵測到該影片沒有 1080p 與 720p，runner 必須：

1. 停止當天作業。
2. 不下載 480p 或更低畫質。
3. 透過 Hermes 既有 Discord 綁定通知使用者。
4. 寫出 `result.json` 與 `download-report.json`。
5. 將任務狀態設為 `ended_for_day_quality_unavailable`。

---

## 10. 每日任務流程

Hermes 每日流程：

```text
讀取本目錄必讀文件
  ↓
建立 TASK-ID
  ↓
建立 task 目錄
  ↓
執行 preflight
  ↓
確認 bootstrap 狀態
  ↓
產生 execution-manifest.json
  ↓
呼叫 /srv/twitch-worker/bin/run-twitch-archive
  ↓
runner 執行 yt-dlp
  ↓
產出 result.json / download-report.json / logs
  ↓
Hermes 驗收任務產物
  ↓
寫入 Hermes 狀態資料庫
  ↓
必要時發送 Discord 通知
```

---

## 11. 必要任務產物

每次 task 目錄至少應包含：

```text
task-envelope.json
execution-manifest.json
preflight-result.json
bootstrap-report.json
result.json
download-report.json
downloaded-items.json
skipped-items.json
failed-items.json
logs/yt-dlp.log
```

若任務被阻擋，也必須產生 `result.json` 與 `download-report.json`，不得只印 stdout。

---

## 12. result.json 最低格式

```json
{
  "project": "twitch-archive",
  "task_id": "TASK-YYYYMMDD-TWITCH-ARCHIVE-NNN",
  "worker_id": "PI16G001",
  "status": "succeeded | blocked | ended_for_day_quality_unavailable | failed",
  "started_at": "ISO-8601",
  "finished_at": "ISO-8601",
  "videos_downloaded": 0,
  "videos_skipped": 0,
  "videos_failed": 0,
  "videos_deleted_by_task": 0,
  "chat_archive_enabled": false,
  "chat_files_written": 0,
  "auto_cleanup_enabled": false,
  "notification_sent": false,
  "notification_channel": "discord_via_hermes_existing_binding"
}
```

---

## 13. 可自修與必須通知的界線

### 13.1 Hermes 可自主修復

Hermes 可自主修復：

1. 缺少 allowlist 內套件。
2. 缺少本專案 managed directories。
3. runner 不存在。
4. runner 權限不是 executable。
5. yt-dlp 版本過舊且可透過 pipx upgrade 更新。
6. task 目錄缺少可重新產生的 manifest。

### 13.2 Hermes 必須通知並停止

Hermes 必須通知並停止：

1. hostname 不是 PI16G001。
2. OS 或 architecture 不符。
3. 無 sudo 且需要安裝套件。
4. Twitch 來源清單為空。
5. primary 與 fallback 輸出路徑都不可用。
6. 剩餘空間低於 1GB。
7. 同時沒有 1080p 與 720p 可下載版本。
8. Discord 通知 runtime 不可用。
9. 需要 token、cookie 或 secret 才能下載。
10. 必讀文件衝突或缺失。

---

## 14. Dry-run 測試規格

Hermes 完成 bootstrap 後，必須支援 dry-run。

Dry-run 不下載影片，只檢查：

1. 必讀文件可讀。
2. manifest 可生成。
3. runner 可執行。
4. yt-dlp 可呼叫。
5. ffmpeg 可呼叫。
6. output root 可寫。
7. Discord 通知介面可被 Hermes runtime 呼叫，但不得發送正式警報，除非標示為測試通知。

Dry-run 結果寫入：

```text
dry-run-result.json
dry-run-report.md
```

---

## 15. 驗收條件

Hermes 自主佈建完成後，必須符合：

1. allowlist 套件安裝完成或已存在。
2. `yt-dlp --version` 可成功執行。
3. `ffmpeg -version` 可成功執行。
4. 所有 managed directories 存在。
5. runner 存在且可執行。
6. dry-run 通過。
7. 低磁碟空間通知策略可被 manifest 表示。
8. 畫質策略可被 manifest 表示。
9. 不保存聊天紀錄策略可被 manifest 表示。
10. 永久保存且不自動刪檔策略可被 manifest 表示。
11. 所有結果都落地成 task artifacts。

---

## 16. 最終判定

只有在本文件與所有必讀文件都可讀，且 bootstrap、preflight、runner、dry-run 與通知能力都通過後，Hermes 才能被視為具備「從套件安裝到自我下載」的自主作業能力。

若尚未完成本文件定義的 bootstrap 與 dry-run，Hermes 只能視為具備規劃能力，不可視為已具備完整自主執行能力。
