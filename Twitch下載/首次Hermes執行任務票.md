# 首次 Hermes 執行任務票

> 適用範圍：`Twitch下載/` 獨立專案。  
> 任務狀態：待 Hermes 在 PI16G001 上執行。  
> 任務目的：將目前已完成的文件規格推進到第一次實機 bootstrap、preflight、runner 產生與 dry-run 驗收。  
> 建立日期：2026-08-09  
> 建立時區：Asia/Taipei

---

## 1. 任務結論

本任務票是 Hermes 第一次接手 `Twitch下載/` 專案時應執行的實機作業清單。

本任務票不要求正式下載 Twitch 影片。

目前 `TWITCH_CHANNEL_SOURCES` 仍可保持空白，因此 Hermes 本次只能執行：

1. 文件讀取與一致性檢查。
2. PI16G001 preflight。
3. allowlist 套件安裝或確認。
4. managed directories 建立或確認。
5. runner 產生或確認。
6. dry-run manifest 產生。
7. dry-run 執行。
8. bootstrap / dry-run 報告產出。
9. 回報是否 `ready_for_channel_sources`。

Hermes 不得在本任務票中進行正式 Twitch 下載。

---

## 2. 任務基本資料

```yaml
FIRST_HERMES_EXECUTION_TICKET:
  ticket_id: "TWITCH-FIRST-HERMES-BOOTSTRAP-20260809"
  project: "twitch-archive"
  context_root: "Twitch下載"
  target_worker_id: "PI16G001"
  target_hostname: "PI16G001"
  timezone: "Asia/Taipei"
  task_type: "bootstrap_preflight_runner_generation_dry_run"
  real_download_allowed: false
  channel_sources_required_for_this_ticket: false
  expected_final_status: "ready_for_channel_sources_or_blocked_with_reason"
```

---

## 3. 必讀文件

Hermes 執行本任務前，必須依序讀取：

1. `Twitch下載/Hermes交接入口.md`
2. `Twitch下載/README.md`
3. `Twitch下載/PI16G001_Hermes_Twitch歸檔Worker設定.md`
4. `Twitch下載/頻道來源維護規格.md`
5. `Twitch下載/下載畫質設定.md`
6. `Twitch下載/聊天紀錄保存策略.md`
7. `Twitch下載/影片保留策略.md`
8. `Twitch下載/Hermes自主佈建與執行規格.md`
9. `Twitch下載/首次Hermes執行任務票.md`

若任一文件缺失、不可讀或互相衝突，Hermes 必須停止，回報：

```text
blocked_missing_or_conflicting_required_docs
```

---

## 4. 本次允許作業

Hermes 本次允許執行：

```yaml
ALLOWED_ACTIONS_FOR_FIRST_EXECUTION:
  read_required_docs: true
  validate_required_docs: true
  run_preflight_on_PI16G001: true
  install_allowlist_packages: true
  create_managed_directories: true
  install_or_update_ytdlp: true
  verify_ffmpeg: true
  verify_jq: true
  verify_python3: true
  verify_pipx: true
  generate_runner: true
  update_runner_if_needed: true
  create_dry_run_manifest: true
  run_dry_run: true
  create_bootstrap_report: true
  create_dry_run_report: true
  test_discord_notification_runtime_as_test_only: true
```

---

## 5. 本次禁止作業

Hermes 本次不得執行：

```yaml
DISALLOWED_ACTIONS_FOR_FIRST_EXECUTION:
  real_twitch_download: true
  add_channel_sources_without_user_instruction: true
  guess_channel_sources: true
  search_twitch_channels: true
  download_chat_archive: true
  enable_chat_downloader: true
  delete_downloaded_videos: true
  install_non_allowlist_packages: true
  save_twitch_token_or_cookie: true
  save_discord_webhook_or_bot_token: true
  modify_other_root_contexts: true
```

---

## 6. 執行步驟

### 6.1 文件檢查

Hermes 必須：

1. 讀取所有必讀文件。
2. 確認 context root 是 `Twitch下載`。
3. 確認不得混用 `多機協作/`、`前台選型/`、`討論3/` 的決策。
4. 確認 `TWITCH_CHANNEL_SOURCES` 可為空。
5. 確認本次不允許正式下載。

產物：

```text
required-docs-check.json
required-docs-check.md
```

---

### 6.2 PI16G001 preflight

Hermes 必須在 PI16G001 上檢查：

```yaml
PREFLIGHT_REQUIRED_CHECKS:
  hostname: "PI16G001"
  os_family: "Debian"
  os_version_expected: "13"
  architecture_expected: "aarch64"
  network_dns_available: true
  network_https_available: true
  twitch_access_check_allowed: true
  sudo_available_if_install_needed: true
  output_root_primary_checked: true
  output_root_fallback_checked: true
  free_space_above_1gb: true
```

若 hostname 不是 `PI16G001`，必須停止，回報：

```text
blocked_wrong_host
```

若需要安裝套件但沒有 sudo，必須停止，回報：

```text
blocked_missing_privilege
```

產物：

```text
preflight-result.json
preflight-report.md
```

---

### 6.3 套件確認與安裝

Hermes 只能安裝 allowlist 內套件。

允許 apt 套件：

```text
ca-certificates
curl
ffmpeg
jq
python3
python3-venv
pipx
```

允許 pipx 工具：

```text
yt-dlp
```

Hermes 應先檢查是否已安裝，再決定是否安裝或更新。

允許命令方向：

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl ffmpeg jq python3 python3-venv pipx
python3 -m pipx ensurepath
pipx install yt-dlp || pipx upgrade yt-dlp
```

驗證命令：

```bash
ffmpeg -version
yt-dlp --version
python3 --version
jq --version
pipx --version
```

產物：

```text
bootstrap-report.json
bootstrap-report.md
```

---

### 6.4 目錄建立

Hermes 必須建立或確認：

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

影片輸出目錄依主設定檔處理：

```text
/mnt/twitch-archive
/srv/twitch-archive
```

若 primary 不存在但 fallback 可用，本任務仍可通過 dry-run，但 report 必須記錄 fallback 狀態。

若 primary 與 fallback 都不可用，必須停止，回報：

```text
blocked_output_root_unavailable
```

---

### 6.5 runner 產生

Hermes 必須產生或確認：

```text
/srv/twitch-worker/bin/run-twitch-archive
```

runner 必須符合：

1. 可執行。
2. 接收 `execution-manifest.json` 路徑作為輸入。
3. 從 manifest 讀取來源、路徑、畫質、聊天策略、保留策略與通知策略。
4. 不硬編碼 Twitch 頻道來源。
5. 不硬編碼輸出路徑。
6. 不硬編碼畫質策略。
7. 不下載聊天紀錄。
8. 不自動刪除影片。
9. 不保存任何 secret。

若已存在 runner，Hermes 可更新，但必須先備份到：

```text
/srv/twitch-worker/backups
```

產物：

```text
runner-generation-report.json
runner-generation-report.md
```

---

### 6.6 dry-run manifest

因為本次不允許正式下載，Hermes 必須產生 dry-run manifest。

最低內容：

```json
{
  "project": "twitch-archive",
  "context_root": "Twitch下載",
  "worker_id": "PI16G001",
  "runner_path": "/srv/twitch-worker/bin/run-twitch-archive",
  "dry_run": true,
  "real_download_allowed": false,
  "channel_sources_status": "empty_by_design",
  "if_channel_sources_empty": "requires_user_input_channel_sources_empty",
  "video_quality_mode": "1080p",
  "fallback_quality_mode": "720p",
  "chat_archive_enabled": false,
  "video_retention_mode": "keep_forever_until_user_deletes",
  "auto_delete_videos": false,
  "notification_channel": "discord_via_hermes_existing_binding"
}
```

產物：

```text
dry-run-execution-manifest.json
```

---

### 6.7 dry-run 執行

dry-run 必須檢查：

1. 必讀文件可讀。
2. manifest 可生成。
3. runner 可執行。
4. yt-dlp 可呼叫。
5. ffmpeg 可呼叫。
6. jq 可呼叫。
7. output root 狀態可判斷。
8. Discord 通知 runtime 可呼叫測試通知，且測試通知必須標示為測試。
9. 頻道來源為空時不會觸發真實下載。

產物：

```text
dry-run-result.json
dry-run-report.md
```

---

## 7. 驗收標準

本任務成功條件：

```yaml
FIRST_EXECUTION_ACCEPTANCE_CRITERIA:
  required_docs_read: true
  no_document_conflict: true
  preflight_passed: true
  allowlist_packages_installed_or_present: true
  ytdlp_available: true
  ffmpeg_available: true
  jq_available: true
  python3_available: true
  managed_directories_ready: true
  runner_exists_and_executable: true
  dry_run_manifest_created: true
  dry_run_passed: true
  no_real_download_attempted: true
  no_channel_source_guessed: true
  no_secret_written: true
```

若全部通過，Hermes 應回報：

```text
ready_for_channel_sources
```

---

## 8. 失敗回報格式

若任一項失敗，Hermes 必須產生：

```text
first-execution-result.json
first-execution-report.md
```

`first-execution-result.json` 最低格式：

```json
{
  "ticket_id": "TWITCH-FIRST-HERMES-BOOTSTRAP-20260809",
  "project": "twitch-archive",
  "worker_id": "PI16G001",
  "status": "blocked",
  "blocked_reason": "<REASON_CODE>",
  "real_download_attempted": false,
  "notification_sent": true,
  "notification_channel": "discord_via_hermes_existing_binding"
}
```

---

## 9. 成功回報格式

若本任務通過，Hermes 必須回報：

```json
{
  "ticket_id": "TWITCH-FIRST-HERMES-BOOTSTRAP-20260809",
  "project": "twitch-archive",
  "worker_id": "PI16G001",
  "status": "ready_for_channel_sources",
  "bootstrap_passed": true,
  "preflight_passed": true,
  "runner_ready": true,
  "dry_run_passed": true,
  "real_download_attempted": false,
  "channel_sources_status": "empty_by_design",
  "next_required_user_action": "provide_twitch_channel_sources"
}
```

---

## 10. 通知規則

本任務只有以下情況需要 Discord 通知：

1. bootstrap 被阻擋。
2. preflight 被阻擋。
3. 套件安裝失敗。
4. runner 產生失敗。
5. dry-run 失敗。
6. Discord 通知能力本身不可用。
7. 任務成功完成，且 Hermes runtime 設定允許發送成功摘要。

所有通知必須透過 Hermes 既有 Discord 綁定，不得保存 webhook 或 token。

---

## 11. 本任務不處理事項

本任務不處理：

1. 實際 Twitch 頻道來源填寫。
2. 正式 Twitch 影片下載。
3. 聊天紀錄下載。
4. 已下載影片刪除。
5. live recording。
6. clips 下載。
7. highlights 下載。
8. 其他根目錄專案整合。

---

## 12. 最終判定

本任務完成後，Hermes 應只回報兩種結論之一：

```text
ready_for_channel_sources
```

或：

```text
blocked_with_reason
```

不得回報「已可正式下載」，除非未來已填入並驗證 `TWITCH_CHANNEL_SOURCES`。
