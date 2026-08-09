# Hermes 交接入口

> 適用範圍：`Twitch下載/` 獨立專案。  
> 決策狀態：已建立 Hermes 交接入口，並已更新第二部分 YouTube 備份流程。  
> 目的：作為 Hermes / Agent 收到本專案後的第一入口，明確定義文件讀取順序、目前專案狀態、可自主執行範圍、必須停止通知的條件與下一步作業順序。  
> 建立日期：2026-08-09  
> 最近更新：2026-08-09，第二部分改為 Twitch 下載前先備份指定影片到 YouTube 頻道。

---

## 1. 使用方式

Hermes / Agent 收到 `Twitch下載/` 專案後，第一份應讀取本文件。

本文件不是新的需求來源，而是現有文件的交接索引與執行順序。

Hermes / Agent 必須依本文件順序讀取其他必讀文件，不得只依賴對話記憶、README 摘要或其他根目錄文件。

---

## 2. 專案目前狀態

```yaml
HERMES_HANDOFF_STATUS:
  project: "twitch-archive"
  context_root: "Twitch下載"
  worker_id: "PI16G001"
  project_goal: "先完成 Hermes bootstrap/dry-run，第二部分在 Twitch 下載前備份指定影片到 YouTube，後續才進入 Twitch VOD 下載"
  documentation_status: "ready_for_hermes_bootstrap_and_dry_run"
  phase_2_youtube_backup_spec: "ready"
  phase_2_youtube_backup_status: "blocked_until_youtube_backup_variables_configured"
  twitch_download_status: "blocked_until_channel_sources_configured_and_youtube_backup_completed"
  channel_sources_status: "empty_by_design"
  bootstrap_required: true
  dry_run_required: true
```

目前判定：

1. 文件規格已足以交給 Hermes 進行 bootstrap 與 dry-run。
2. `TWITCH_CHANNEL_SOURCES` 目前可以保持空白。
3. 若 `TWITCH_CHANNEL_SOURCES` 仍為空，Hermes 不得建立正式 Twitch 下載任務。
4. 第二部分不是 Twitch 下載；第二部分是在 Twitch 下載前先備份指定影片到 YouTube 頻道。
5. YouTube 備份需要使用者設定備份來源、目標頻道與 Hermes runtime OAuth。
6. YouTube 備份失敗時，Hermes 必須停止後續 Twitch 下載並通知使用者。
7. 頻道來源必須由使用者或授權流程明確填入，不得由 Agent 猜測、搜尋或自行新增。
8. Hermes 完成 bootstrap、preflight、runner、dry-run 與通知能力驗收後，才可視為具備完整自主執行基礎。

---

## 3. 文件讀取順序

Hermes / Agent 必須依以下順序讀取文件：

1. `Twitch下載/Hermes交接入口.md`
2. `Twitch下載/README.md`
3. `Twitch下載/PI16G001_Hermes_Twitch歸檔Worker設定.md`
4. `Twitch下載/頻道來源維護規格.md`
5. `Twitch下載/下載畫質設定.md`
6. `Twitch下載/聊天紀錄保存策略.md`
7. `Twitch下載/影片保留策略.md`
8. `Twitch下載/Hermes自主佈建與執行規格.md`
9. `Twitch下載/首次Hermes執行任務票.md`
10. `Twitch下載/第二部分YouTube頻道備份功能規格.md`

不得使用：

```text
Twitch下載/第二部分正式每日下載功能規格.md
```

作為第二部分執行依據。該文件已被取代，只保留為錯誤規格更正記錄。

---

## 4. 目前已確認決策摘要

Hermes / Agent 可將以下視為已確認決策：

```yaml
CONFIRMED_DECISIONS:
  task_owner: "Hermes agent"
  worker: "PI16G001"
  timezone: "Asia/Taipei"

  phase_1_first_execution:
    purpose: "bootstrap_preflight_runner_generation_dry_run"
    real_twitch_download_allowed: false

  phase_2_youtube_backup:
    purpose: "backup_specified_videos_to_youtube_before_twitch_download"
    must_run_before_twitch_download: true
    source_video_root: "requires_user_configuration"
    target_youtube_channel: "requires_user_or_hermes_runtime_configuration"
    oauth_secret_location: "managed_by_hermes_runtime_not_in_repository"
    default_privacy_status: "private"
    delete_local_video_after_upload: false
    if_backup_fails: "block_twitch_download_and_notify_user"

  twitch_download_scope:
    vods: true
    highlights: false
    clips: false
    live_recording: false

  chat_archive:
    enabled: false

  video_retention:
    mode: "keep_forever_until_user_deletes"
    auto_delete: false

  quality:
    primary: "1080p"
    fallback: "720p"
    if_1080p_and_720p_unavailable: "notify_user_and_end_daily_job"
    allow_below_720p: false

  notification:
    channel: "discord_via_hermes_existing_binding"

  disk:
    min_free_space_gb: 1
    if_below_minimum: "notify_user_via_discord_and_block_task"

  channel_sources:
    truth_source: "TWITCH_CHANNEL_SOURCES"
    current_status: "empty_by_design"
    if_empty: "requires_user_input_channel_sources_empty"
```

---

## 5. Hermes 可自主執行的範圍

在不填入實際 Twitch 頻道來源、不設定 YouTube secrets 的前提下，Hermes 可以自主執行：

1. 讀取必讀文件。
2. 檢查文件是否缺失或互相衝突。
3. 在 PI16G001 上執行 preflight。
4. 安裝 allowlist 內套件。
5. 建立本專案管理目錄。
6. 安裝或更新 `yt-dlp`。
7. 確認 `ffmpeg`、`jq`、`python3`、`pipx` 可用。
8. 產生或更新 `/srv/twitch-worker/bin/run-twitch-archive`。
9. 產生 dry-run manifest。
10. 執行 dry-run。
11. 產出 bootstrap 與 dry-run 報告。
12. 測試 Hermes 既有 Discord 通知能力，但測試通知必須標示為測試。

Hermes 不得在頻道來源空白時進行正式 Twitch 影片下載。

Hermes 不得在 YouTube 備份來源、目標頻道或 OAuth runtime 未設定時執行第二部分上傳。

---

## 6. Hermes 必須停止並通知使用者的條件

Hermes 遇到以下情況必須停止並通知使用者：

1. 必讀文件缺失、不可讀或互相衝突。
2. 目前主機不是 `PI16G001`。
3. OS 或 architecture 與設定不符。
4. 需要 sudo 權限但 runtime 沒有權限。
5. 套件安裝需要 allowlist 以外套件。
6. `TWITCH_CHANNEL_SOURCES` 為空且即將建立正式 Twitch 下載任務。
7. YouTube 備份來源目錄未設定且即將執行第二部分。
8. YouTube 目標頻道未設定且即將執行第二部分。
9. Hermes runtime 沒有可用 YouTube OAuth 且即將執行第二部分。
10. YouTube 備份失敗。
11. 來源 URL 不是 Twitch URL。
12. 來源中疑似包含 token、cookie、password 或 secret。
13. primary 與 fallback 輸出路徑都不可用。
14. 剩餘空間低於 1GB。
15. 影片同時沒有 1080p 與 720p 可下載版本。
16. Discord 通知 runtime 不可用。
17. Twitch 下載需要 Twitch token、cookie 或登入狀態。

---

## 7. 首次交接作業順序

Hermes 第一次收到本專案時，應依序執行：

```text
讀取 Hermes交接入口.md
  ↓
讀取 README.md
  ↓
讀取所有必讀文件
  ↓
確認 TWITCH_CHANNEL_SOURCES 狀態
  ↓
若來源為空：只允許 bootstrap 與 dry-run，不允許正式 Twitch 下載
  ↓
執行 PI16G001 preflight
  ↓
安裝 allowlist 套件或確認已存在
  ↓
建立 managed directories
  ↓
產生 /srv/twitch-worker/bin/run-twitch-archive
  ↓
產生 dry-run manifest
  ↓
執行 dry-run
  ↓
產出 bootstrap-report 與 dry-run-report
  ↓
回報是否 ready_for_channel_sources
```

---

## 8. 第二部分作業順序

當第一次 Hermes 任務已回報 `ready_for_channel_sources`，且使用者已設定 YouTube 備份來源、目標頻道與 Hermes runtime OAuth 後，Hermes 才能執行第二部分：

```text
讀取 第二部分YouTube頻道備份功能規格.md
  ↓
驗證 YouTube 備份來源目錄
  ↓
驗證 YouTube 目標頻道
  ↓
驗證 Hermes runtime OAuth 可用
  ↓
掃描待備份影片
  ↓
排除已上傳與不合格檔案
  ↓
上傳到 YouTube 頻道
  ↓
記錄 YouTube video id 與 upload archive
  ↓
產出 youtube-backup-result / youtube-backup-report
  ↓
若成功或無待備份影片，才允許後續 Twitch 下載
```

---

## 9. 正式 Twitch 下載前檢查清單

正式 Twitch 下載前，Hermes 必須確認：

```yaml
READY_FOR_TWITCH_DOWNLOAD_CHECKLIST:
  required_docs_read: true
  no_document_conflict: true
  bootstrap_passed: true
  preflight_passed: true
  runner_exists_and_executable: true
  dry_run_passed: true
  notification_runtime_available: true
  phase_2_youtube_backup_succeeded_or_no_pending_items: true
  output_root_available: true
  free_space_above_1gb: true
  channel_sources_non_empty: true
  all_enabled_sources_user_confirmed: true
  no_secret_in_sources: true
```

只要其中任一項不通過，Hermes 不得正式 Twitch 下載。

---

## 10. 頻道來源仍空時的回報格式

若 `TWITCH_CHANNEL_SOURCES` 為空，Hermes 應回報：

```json
{
  "project": "twitch-archive",
  "worker_id": "PI16G001",
  "status": "blocked",
  "blocked_reason": "requires_user_input_channel_sources_empty",
  "allowed_next_actions": [
    "bootstrap",
    "preflight",
    "runner_generation",
    "dry_run",
    "phase_2_youtube_backup_if_configured"
  ],
  "disallowed_actions": [
    "real_twitch_download"
  ]
}
```

---

## 11. 交接完成判定

Hermes 交接完成不代表可以立即 Twitch 下載。

交接完成代表：

1. Hermes 已讀完所有必讀文件。
2. Hermes 理解本專案 context 邊界。
3. Hermes 知道哪些事可自主處理。
4. Hermes 知道哪些事必須停止通知使用者。
5. Hermes 知道第二部分是 YouTube 備份，不是 Twitch 下載。
6. Hermes 知道 YouTube 備份失敗時必須阻擋 Twitch 下載。
7. Hermes 知道頻道來源目前刻意留空，不得猜測。

只有在 YouTube 備份完成或無待備份影片、頻道來源填入且通過驗證、bootstrap 通過、dry-run 通過、通知能力可用後，才可進入正式 Twitch 下載。

---

## 12. 已確認事項

- 本文件是 Hermes 的第一入口。
- 本文件不新增新的下載需求。
- 本文件不填入任何實際 Twitch 頻道。
- 本文件不保存任何 secret。
- 第二部分正確文件是 `第二部分YouTube頻道備份功能規格.md`。
- `第二部分正式每日下載功能規格.md` 已被取代，不得作為第二部分執行依據。
- 本文件只整理讀取順序、交接狀態、允許作業、停止條件與正式 Twitch 下載前檢查清單。
