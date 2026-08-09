# PI16G001 Hermes Twitch 歸檔 Worker 設定

> 文件用途：保存 `Twitch下載/` 獨立專案中，PI16G001 上由 Hermes 管理的 Twitch 定時下載任務變數。  
> 適用範圍：僅限 `Twitch下載/` context。  
> 使用者需求：Twitch 影片每日定時下載工作交由 Hermes agent 管理。  
> 建立日期：2026-08-09

---

## 1. Context 邊界

本文件屬於 `Twitch下載/` 獨立專案。

Agent 必須遵守：

1. 不得將本文件視為 `多機協作/` 的一部分。
2. 不得自動套用 `多機協作/`、`前台選型/`、`討論3/` 或其他根目錄的技術決策。
3. 若需要引用其他目錄，只能作為外部參考，且必須明確標注來源。
4. 本專案內若使用 Hermes 名稱，代表本專案自己的任務管理設計，不等同於其他目錄中的 Hermes 架構。
5. 本文件中的變數是本專案 Twitch 下載任務的主要設定來源。

---

## 2. Agent 讀取規則

所有 Hermes / Worker Agent 在規劃、建立、派送或執行 Twitch 歸檔任務前，必須先讀取：

1. `Twitch下載/README.md`
2. `Twitch下載/PI16G001_Hermes_Twitch歸檔Worker設定.md`

本文件中的「任務變數區塊」是 Twitch 歸檔任務的設定來源之一。Agent 不得將 Twitch 頻道、下載來源、輸出路徑或排程硬編碼在 prompt、shell script 或 execution manifest 中。

Agent 必須遵守以下規則：

1. 每次建立 Twitch 歸檔任務前，先讀取本文件。
2. 解析 `HERMES_TWITCH_ARCHIVE_VARIABLES` 區塊中的變數。
3. 將變數轉換成當次任務的 `task-envelope.json` 與 `execution-manifest.json`。
4. 若 `TWITCH_CHANNEL_SOURCES` 為空，Agent 必須停止建立下載任務，並回報 `requires_user_input`。
5. 若變數與實機狀態不一致，Agent 必須標示為待確認，不得自行猜測。
6. 若需要修改頻道清單或排程，應更新本文件，而不是修改 worker 腳本。
7. 本文件不得保存 Twitch 帳號密碼、OAuth token、cookie、API secret 或其他機密資訊。

---

## 3. 任務變數區塊

以下區塊是 Hermes / Agent 應讀取的設定來源。

```yaml
HERMES_TWITCH_ARCHIVE_VARIABLES:
  task_profile: "twitch_daily_vod_archive"
  project: "twitch-archive"
  context_root: "Twitch下載"

  hermes:
    controller_id: "hermes-twitch-controller"
    control_root: "/srv/hermes-twitch"
    task_root: "/srv/hermes-twitch/tasks"
    state_db: "/srv/hermes-twitch/state/twitch-archive.db"

  worker:
    worker_id: "PI16G001"
    role: "twitch-archive-worker"
    hostname: "PI16G001"
    machine_model: "Raspberry Pi 5 Model B Rev 1.1"
    os: "Debian GNU/Linux 13 trixie"
    architecture: "aarch64"
    memory: "16GB"
    worker_root: "/srv/twitch-worker"
    runner_path: "/srv/twitch-worker/bin/run-twitch-archive"

  schedule:
    managed_by: "hermes"
    timezone: "Asia/Taipei"
    recurrence: "daily"
    preferred_start_time: "03:30"
    allow_random_delay_minutes: 10
    prevent_overlap: true

  twitch:
    download_scope:
      vods: true
      highlights: false
      clips: false
      live_recording: false
    TWITCH_CHANNEL_SOURCES: []
    # 範例：
    # TWITCH_CHANNEL_SOURCES:
    #   - channel_name: "example_channel"
    #     source_url: "https://www.twitch.tv/example_channel/videos"
    #     enabled: true
    #     note: "待使用者確認授權與保存需求"

  downloader:
    tool: "yt-dlp"
    output_format: "mp4"
    write_info_json: true
    write_thumbnail: true
    continue_partial_download: true
    ignore_item_errors: true
    use_download_archive: true

  storage:
    preferred_output_root: "/mnt/twitch-archive"
    fallback_output_root: "/srv/twitch-archive"
    archive_state_file: "/var/lib/twitch-archiver/archive.txt"
    channel_config_file: "/var/lib/twitch-archiver/channels.txt"
    log_dir: "/var/log/twitch-archiver"
    min_free_space_gb: 20

  task_artifacts:
    required_files:
      - "task-envelope.json"
      - "execution-manifest.json"
      - "result.json"
      - "download-report.json"
      - "downloaded-items.json"
      - "skipped-items.json"
      - "failed-items.json"
      - "logs/yt-dlp.log"

  failure_policy:
    if_channel_list_empty: "requires_user_input"
    if_output_root_missing: "blocked"
    if_free_space_below_minimum: "blocked"
    if_single_video_fails: "continue_and_report_failed_item"
    if_downloader_missing: "blocked"
```

---

## 4. Agent 執行說明

Hermes 建立每日任務時，應依本文件產生任務資料。

建議 task 命名：

```text
TASK-YYYYMMDD-TWITCH-ARCHIVE-NNN
```

建議 task request：

```text
依照 Twitch下載/PI16G001_Hermes_Twitch歸檔Worker設定.md 中的 HERMES_TWITCH_ARCHIVE_VARIABLES，下載 TWITCH_CHANNEL_SOURCES 內啟用來源的新 Twitch VOD，避免重複下載，並產出任務結果摘要。
```

Worker 實際執行時，應使用 manifest 中的變數，不得自行覆寫 Twitch 來源。

---

## 5. 頻道來源填寫規則

`TWITCH_CHANNEL_SOURCES` 由使用者或授權 Agent 維護。

每個來源至少應包含：

```yaml
- channel_name: "頻道名稱"
  source_url: "https://www.twitch.tv/頻道名稱/videos"
  enabled: true
  note: "用途或授權備註"
```

若來源暫停下載，應將 `enabled` 改成 `false`，不要直接刪除，除非使用者明確要求。

---

## 6. 設計原則

- Hermes 管任務生命週期。
- PI16G001 worker 管實際執行。
- yt-dlp 只負責下載。
- systemd 只負責啟動與保底，不作為任務真相來源。
- Twitch 來源與排程設定以本文件變數為準。
- 任務狀態與派工真相應寫入本專案自己的 Hermes 狀態資料庫，不依賴對話記憶。
