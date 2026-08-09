# Hermes 交接入口

> 適用範圍：`Twitch下載/` 獨立專案。  
> 決策狀態：已建立 Hermes 交接入口。  
> 目的：作為 Hermes / Agent 收到本專案後的第一入口，明確定義文件讀取順序、目前專案狀態、可自主執行範圍、必須停止通知的條件與下一步作業順序。  
> 建立日期：2026-08-09

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
  project_goal: "每天定時下載 Twitch VOD，並由 Hermes 管理任務生命週期"
  documentation_status: "ready_for_hermes_bootstrap_and_dry_run"
  actual_download_status: "blocked_until_channel_sources_configured"
  channel_sources_status: "empty_by_design"
  bootstrap_required: true
  dry_run_required: true
```

目前判定：

1. 文件規格已足以交給 Hermes 進行 bootstrap 與 dry-run。
2. `TWITCH_CHANNEL_SOURCES` 目前可以保持空白。
3. 若 `TWITCH_CHANNEL_SOURCES` 仍為空，Hermes 不得建立正式下載任務。
4. 頻道來源必須由使用者或授權流程明確填入，不得由 Agent 猜測、搜尋或自行新增。
5. Hermes 完成 bootstrap、preflight、runner、dry-run 與通知能力驗收後，才可視為具備完整自主執行能力。

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

讀取理由：

1. 先讀交接入口，取得目前狀態與流程。
2. 再讀 README，確認 context 邊界與必讀文件。
3. 再讀主設定檔，取得任務變數。
4. 再讀各策略文件，確認來源、畫質、聊天、保留與佈建規則。
5. 最後依自主佈建規格執行 bootstrap、dry-run 或每日任務。

---

## 4. 目前已確認決策摘要

Hermes / Agent 可將以下視為已確認決策：

```yaml
CONFIRMED_DECISIONS:
  task_owner: "Hermes agent"
  worker: "PI16G001"
  recurrence: "daily"
  timezone: "Asia/Taipei"
  download_scope:
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

在不填入實際 Twitch 頻道來源的前提下，Hermes 可以自主執行：

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

---

## 6. Hermes 必須停止並通知使用者的條件

Hermes 遇到以下情況必須停止並通知使用者：

1. 必讀文件缺失、不可讀或互相衝突。
2. 目前主機不是 `PI16G001`。
3. OS 或 architecture 與設定不符。
4. 需要 sudo 權限但 runtime 沒有權限。
5. 套件安裝需要 allowlist 以外套件。
6. `TWITCH_CHANNEL_SOURCES` 為空且即將建立正式下載任務。
7. 來源 URL 不是 Twitch URL。
8. 來源中疑似包含 token、cookie、password 或 secret。
9. primary 與 fallback 輸出路徑都不可用。
10. 剩餘空間低於 1GB。
11. 影片同時沒有 1080p 與 720p 可下載版本。
12. Discord 通知 runtime 不可用。
13. 下載需要 Twitch token、cookie 或登入狀態。

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
若來源為空：只允許 bootstrap 與 dry-run，不允許正式下載
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

## 8. 正式下載前檢查清單

正式下載前，Hermes 必須確認：

```yaml
READY_FOR_REAL_DOWNLOAD_CHECKLIST:
  required_docs_read: true
  no_document_conflict: true
  bootstrap_passed: true
  preflight_passed: true
  runner_exists_and_executable: true
  dry_run_passed: true
  notification_runtime_available: true
  output_root_available: true
  free_space_above_1gb: true
  channel_sources_non_empty: true
  all_enabled_sources_user_confirmed: true
  no_secret_in_sources: true
```

只要其中任一項不通過，Hermes 不得正式下載。

---

## 9. 頻道來源仍空時的回報格式

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
    "dry_run"
  ],
  "disallowed_actions": [
    "real_twitch_download"
  ]
}
```

---

## 10. 交接完成判定

Hermes 交接完成不代表可以立即下載。

交接完成代表：

1. Hermes 已讀完所有必讀文件。
2. Hermes 理解本專案 context 邊界。
3. Hermes 知道哪些事可自主處理。
4. Hermes 知道哪些事必須停止通知使用者。
5. Hermes 知道頻道來源目前刻意留空，不得猜測。

只有在頻道來源填入且通過驗證、bootstrap 通過、dry-run 通過、通知能力可用後，才可進入正式每日下載。

---

## 11. 已確認事項

- 本文件是 Hermes 的第一入口。
- 本文件不新增新的下載需求。
- 本文件不填入任何實際 Twitch 頻道。
- 本文件不保存任何 secret。
- 本文件只整理讀取順序、交接狀態、允許作業、停止條件與正式下載前檢查清單。
