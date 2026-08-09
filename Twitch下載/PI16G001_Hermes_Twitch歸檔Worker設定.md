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
5. Twitch 影片成品、metadata、暫存、archive 狀態檔、頻道清單檔與 log 路徑，必須全部從 `storage.STORAGE_PATH_VARIABLES` 讀取。
6. Agent 不得在 prompt、shell script、systemd unit 或 execution manifest 中自行寫死任何存放路徑。
7. 若需要變更存放路徑，應更新本文件的 `storage.STORAGE_PATH_VARIABLES`，而不是修改 worker 腳本。
8. 若變數與實機狀態不一致，Agent 必須標示為待確認，不得自行猜測。
9. 若需要修改頻道清單或排程，應更新本文件，而不是修改 worker 腳本。
10. 本文件不得保存 Twitch 帳號密碼、OAuth token、cookie、API secret 或其他機密資訊。

---

## 3. 任務變數區塊

以下區塊是 Hermes / Agent 應讀取的設定來源。

> 註解規則：  
> - 每個變數旁的 `#` 註解都是給 Agent 與維運人員閱讀的說明。  
> - Agent 解析 YAML 時應忽略註解，但在規劃任務時必須遵守註解中的限制。  
> - 若要變更任務行為，優先修改本變數區塊，而不是修改 prompt、shell script 或 systemd unit。

```yaml
# Twitch 歸檔專案的最高層設定根節點。
# Agent 必須從這個節點開始解析，不得只讀取局部欄位後自行補推其他值。
HERMES_TWITCH_ARCHIVE_VARIABLES:
  # 任務設定檔名稱。
  # 用途：讓 Hermes / Worker 分辨這是一個「每日 Twitch VOD 歸檔」任務，而不是一般任務。
  # 修改規則：除非專案類型改變，否則不要更名；若更名，所有 task template 與 runner 判斷都要同步更新。
  task_profile: "twitch_daily_vod_archive"

  # 專案識別名稱。
  # 用途：寫入 task-envelope、result.json、log、DB 狀態與報表，方便日後查詢。
  # 修改規則：只代表本獨立專案，不得沿用其他根目錄的 project 名稱。
  project: "twitch-archive"

  # Repository 內的 context 根目錄。
  # 用途：提醒 Agent 本任務只能使用 Twitch下載/ 內的設計決策作為主要依據。
  # 修改規則：本專案已切分為獨立根目錄，因此不得改回 多機協作。
  context_root: "Twitch下載"

  # Hermes 控制平面設定。
  # 用途：定義本獨立專案自己的 Hermes 任務管理位置。
  # 注意：這裡的 Hermes 不等同於其他目錄內的 Hermes 架構。
  hermes:
    # Hermes 控制器識別碼。
    # 用途：寫入 task 與 DB，表示這批 Twitch 歸檔任務由哪個 controller 管理。
    # 修改規則：若部署多個控制器，必須保持全域唯一且可讀。
    controller_id: "hermes-twitch-controller"

    # Hermes 控制平面根目錄。
    # 用途：存放本專案 Hermes 的設定、狀態、任務目錄與必要執行資料。
    # 修改規則：若路徑變更，task_root 與 state_db 通常也要同步檢查。
    control_root: "/srv/hermes-twitch"

    # Hermes 任務目錄根路徑。
    # 用途：每次建立 Twitch 歸檔任務時，Hermes 應在此目錄下建立 TASK-ID 子目錄。
    # 內容：task-envelope.json、execution-manifest.json、result.json、報告與 log 索引。
    task_root: "/srv/hermes-twitch/tasks"

    # Hermes 狀態資料庫路徑。
    # 用途：保存任務狀態、派工狀態、重試資訊與 worker 執行摘要。
    # 注意：這是本 Twitch下載 專案自己的狀態資料庫，不得與其他獨立目錄共用。
    state_db: "/srv/hermes-twitch/state/twitch-archive.db"

  # Worker 節點設定。
  # 用途：描述實際負責下載 Twitch VOD 的機器與 runner 位置。
  worker:
    # Worker 唯一識別碼。
    # 用途：寫入 task、result、DB 與 log，表示任務由哪台機器執行。
    # 來源：使用者提供的樹莓派主機名稱 PI16G001。
    worker_id: "PI16G001"

    # Worker 角色名稱。
    # 用途：讓 Hermes 判斷此 worker 可承接 Twitch 歸檔任務。
    # 修改規則：若未來同一台機器承接其他任務，請新增角色而不是混用此值。
    role: "twitch-archive-worker"

    # 實機 hostname。
    # 用途：對照 SSH、systemd、log 與現場維運資訊。
    # 注意：若實機 hostname 改變，這裡也要同步更新。
    hostname: "PI16G001"

    # 實機型號。
    # 用途：讓 Agent 在設計下載併發、儲存與效能時知道硬體限制。
    # 來源：使用者提供的 /proc/device-tree/model 輸出。
    machine_model: "Raspberry Pi 5 Model B Rev 1.1"

    # 作業系統版本。
    # 用途：影響套件安裝方式、systemd 行為與 Python / yt-dlp 安裝策略。
    # 來源：使用者提供的 /etc/os-release 輸出。
    os: "Debian GNU/Linux 13 trixie"

    # CPU / OS 架構。
    # 用途：選擇 ARM64 相容的 binary、套件與容器映像。
    # 來源：使用者提供的 uname / lscpu 輸出。
    architecture: "aarch64"

    # 記憶體容量摘要。
    # 用途：讓 Agent 估算可承受的下載、metadata 處理與暫存工作量。
    # 注意：這是規格摘要，不是即時 free memory；即時狀態仍需執行時檢查。
    memory: "16GB"

    # Worker 工作根目錄。
    # 用途：存放 Twitch worker 的 runner、設定、任務副本與本機執行資料。
    # 修改規則：此路徑屬於本專案，避免使用 /srv/agent 以免和其他專案混用。
    worker_root: "/srv/twitch-worker"

    # Twitch 下載 runner 的固定入口。
    # 用途：Hermes 派工時呼叫此 wrapper，而不是直接呼叫 yt-dlp。
    # 注意：runner 必須讀取 execution-manifest.json，不得自行硬編碼來源或路徑。
    runner_path: "/srv/twitch-worker/bin/run-twitch-archive"

  # 排程設定。
  # 用途：描述 Hermes 應如何建立每日 Twitch 歸檔任務。
  schedule:
    # 排程管理者。
    # 用途：明確表示任務生命週期由 Hermes 管理，而不是由 cron 或 systemd timer 作為真相來源。
    managed_by: "hermes"

    # 排程時區。
    # 用途：所有 preferred_start_time、報告日期與 task_id 日期都應以此時區解讀。
    # 修改規則：若改時區，要同步檢查任務命名與報表日期。
    timezone: "Asia/Taipei"

    # 週期類型。
    # 用途：告訴 Hermes 這是每日任務。
    # 可選方向：目前固定 daily；若未來改成 hourly / weekly，需同步調整任務命名與重試策略。
    recurrence: "daily"

    # 每日偏好的啟動時間。
    # 用途：Hermes 應盡量在此時間建立或派送任務。
    # 注意：這不是 yt-dlp 內部參數，也不是 systemd timer 的唯一真相。
    preferred_start_time: "03:30"

    # 允許的隨機延遲分鐘數。
    # 用途：避免每天精準同秒啟動造成網路或平台請求尖峰。
    # 行為：Hermes 可在 preferred_start_time 後最多延遲此分鐘數派工。
    allow_random_delay_minutes: 10

    # 是否禁止任務重疊。
    # 用途：避免前一次下載未結束時又啟動下一次，導致重複下載或寫入衝突。
    # 行為：true 時，Hermes / runner 應檢查 active task 或 lock。
    prevent_overlap: true

  # Twitch 來源與下載範圍設定。
  # 用途：定義要抓取哪一類 Twitch 內容，以及要從哪些頻道或 URL 取得影片。
  twitch:
    # 下載範圍設定。
    # 用途：明確限制本專案目前只抓取哪些 Twitch 內容類型。
    download_scope:
      # 是否下載 VOD。
      # 用途：true 表示下載頻道過去直播影片，是本專案 MVP 的主要目標。
      vods: true

      # 是否下載 Highlight。
      # 用途：false 表示目前不抓精華片段；若改 true，runner 需要支援對應 URL 或 yt-dlp filter。
      highlights: false

      # 是否下載 Clips。
      # 用途：false 表示目前不抓 clips；若改 true，需要另外定義 clips 來源與去重方式。
      clips: false

      # 是否進行直播中即時錄製。
      # 用途：false 表示目前只抓已產生的 VOD，不做 live recording。
      # 注意：若改 true，通常需要 streamlink 或長駐服務設計，不只是 yt-dlp 批次任務。
      live_recording: false

    # Twitch 頻道或影片來源清單。
    # 用途：Agent 每次建立任務時必須讀取此清單；空清單代表尚未指定下載來源。
    # 行為：若為空，依 failure_policy.if_channel_list_empty 回報 requires_user_input。
    TWITCH_CHANNEL_SOURCES: []

    # TWITCH_CHANNEL_SOURCES 範例格式。
    # channel_name：Twitch 頻道名稱，作為資料夾命名、報表分類與任務摘要使用。
    # source_url：頻道影片頁或特定影片來源 URL，runner 以此交給 yt-dlp。
    # enabled：是否啟用此來源；暫停下載時應改 false，而不是直接刪除。
    # note：用途、授權或維運備註；不得放 token、cookie 或密碼。
    # TWITCH_CHANNEL_SOURCES:
    #   - channel_name: "example_channel"
    #     source_url: "https://www.twitch.tv/example_channel/videos"
    #     enabled: true
    #     note: "待使用者確認授權與保存需求"

  # 下載工具設定。
  # 用途：定義 runner 使用的下載工具與共同行為。
  downloader:
    # 下載工具名稱。
    # 用途：目前指定使用 yt-dlp；runner 應檢查此工具是否存在。
    # 修改規則：若改成其他工具，需要同步更新 runner 與參數轉換規則。
    tool: "yt-dlp"

    # 影片輸出封裝格式。
    # 用途：指示 runner 優先將下載結果整理為 mp4。
    # 注意：實際格式仍可能受 Twitch 原始串流與 ffmpeg 合併能力影響。
    output_format: "mp4"

    # 是否寫出 yt-dlp 的 info.json。
    # 用途：保存影片 metadata，方便日後整理、查詢、去重與報表生成。
    write_info_json: true

    # 是否下載縮圖。
    # 用途：保存影片封面，方便日後建立索引或檢視頁面。
    write_thumbnail: true

    # 是否允許續傳未完成檔案。
    # 用途：網路中斷或任務重跑時，避免從頭下載大檔案。
    continue_partial_download: true

    # 單一影片失敗時是否繼續處理其他影片。
    # 用途：避免一支 VOD 失敗導致整批任務中止。
    # 行為：失敗項目應寫入 failed-items.json。
    ignore_item_errors: true

    # 是否使用下載封存狀態檔。
    # 用途：避免重複下載已成功保存的影片。
    # 對應路徑：storage.STORAGE_PATH_VARIABLES.archive_state_file。
    use_download_archive: true

  # 儲存與路徑設定。
  # 用途：所有影片、metadata、暫存、log、狀態與任務產物路徑都集中在這裡。
  storage:
    # 所有存放路徑變數集合。
    # 用途：Agent 與 runner 必須從此區塊取得路徑，不得寫死在任何腳本或 manifest 中。
    STORAGE_PATH_VARIABLES:
      # 主要影片輸出根目錄。
      # 用途：正式影片、info.json、thumbnail 的優先存放位置。
      # 建議：正式環境應掛載外接 SSD 或 NAS 到此路徑。
      output_root_primary: "/mnt/twitch-archive"

      # 備援影片輸出根目錄。
      # 用途：primary 不存在、未掛載或不可寫時的備援位置。
      # 注意：目前此路徑通常位於本機 root filesystem；長期大量影片不建議只靠 microSD。
      output_root_fallback: "/srv/twitch-archive"

      # 暫存下載工作目錄。
      # 用途：保存下載中的暫存檔、部分檔案或中間處理資料。
      # 注意：目前 /tmp 可能是 tmpfs，適合短期暫存，但不適合保存大批長期資料。
      temp_download_root: "/tmp/twitch-archive-work"

      # yt-dlp download archive 狀態檔。
      # 用途：記錄已成功處理的影片 ID，避免下次重複下載。
      # 注意：此檔很重要，應納入備份或至少在報告中標示位置。
      archive_state_file: "/var/lib/twitch-archiver/archive.txt"

      # 頻道清單輸出檔。
      # 用途：runner 可將 TWITCH_CHANNEL_SOURCES 轉成 yt-dlp 可讀的 URL 清單。
      # 注意：此檔是由變數生成的執行期產物，不應成為人工維護的唯一真相來源。
      channel_config_file: "/var/lib/twitch-archiver/channels.txt"

      # log 目錄。
      # 用途：保存 runner、yt-dlp、錯誤診斷與排程執行紀錄。
      # 注意：log 不得包含 token、cookie、密碼或其他 secret。
      log_dir: "/var/log/twitch-archiver"

      # Hermes 任務根目錄。
      # 用途：保存 Hermes 建立的 task-envelope、execution-manifest、result 與任務報告。
      # 關聯：應與 hermes.task_root 保持一致，若不同必須在文件中說明原因。
      hermes_task_root: "/srv/hermes-twitch/tasks"

      # Worker 執行結果根目錄。
      # 用途：保存 worker 在本機產出的 result、download-report 與執行摘要。
      # 注意：影片大檔不一定放這裡；影片應依 output_root_* 決定。
      worker_result_root: "/srv/twitch-worker/results"

    # 正式使用哪一個 output root 變數。
    # 用途：讓 Agent 透過變數名稱切換輸出位置，而不是直接改 runner。
    # 合法值：通常為 output_root_primary 或 output_root_fallback。
    active_output_root_variable: "output_root_primary"

    # 是否允許 primary 不可用時改用 fallback。
    # 用途：提高任務可用性；但 fallback 可能容量較小，必須在報告中註明。
    allow_fallback_output_root: true

    # metadata sidecar 存放策略。
    # 用途：決定 info.json、thumbnail 等副檔案放在哪裡。
    # 目前值：same_directory_as_video 表示與影片放在同一個頻道資料夾。
    metadata_sidecar_policy: "same_directory_as_video"

    # 影片輸出路徑模板。
    # 用途：runner 依此產生最終檔案路徑。
    # 變數說明：output_root 來自 active_output_root_variable；channel_name 來自來源設定；upload_date/video_id/safe_title/ext 來自 yt-dlp metadata。
    output_path_template: "{output_root}/{channel_name}/{upload_date}_{video_id}_{safe_title}.{ext}"

    # 最低可用空間門檻，單位 GB。
    # 用途：開始任務前檢查輸出根目錄剩餘容量；低於此值時應阻塞任務。
    # 注意：此值不是保留空間保證，只是任務啟動門檻。
    min_free_space_gb: 20

  # 任務產物設定。
  # 用途：定義每次 Twitch 歸檔任務完成後，task 目錄必須出現哪些檔案。
  task_artifacts:
    # 必要產物檔案清單。
    # 用途：Hermes 驗收任務時可以檢查這些檔案是否存在。
    required_files:
      # Hermes 建立的任務外殼，保存使用者需求與流程級資訊。
      - "task-envelope.json"

      # Hermes 派送給 worker 的執行設定，必須由本文件變數轉換而來。
      - "execution-manifest.json"

      # 任務總結果，保存 succeeded / failed / blocked 等最終狀態。
      - "result.json"

      # 下載摘要報告，保存下載數、跳過數、失敗數、實際輸出路徑與空間狀態。
      - "download-report.json"

      # 本次成功下載或確認完成的影片項目清單。
      - "downloaded-items.json"

      # 本次因已存在、已封存、停用或不符合條件而跳過的項目清單。
      - "skipped-items.json"

      # 本次下載失敗的項目清單，包含錯誤摘要但不得包含 secret。
      - "failed-items.json"

      # yt-dlp 或 runner 的主要執行 log。
      - "logs/yt-dlp.log"

  # 失敗處理策略。
  # 用途：定義 Hermes / runner 面對常見阻塞情況時應採取的標準行為。
  failure_policy:
    # 頻道來源清單為空時的處理。
    # 行為：不建立實際下載任務，回報需要使用者提供來源。
    if_channel_list_empty: "requires_user_input"

    # 主要輸出根目錄不存在、未掛載或不可寫時的處理。
    # 行為：若允許 fallback 且 fallback 可用，改用 fallback；否則阻塞任務。
    if_output_root_missing: "blocked_unless_fallback_available"

    # 可用空間低於 min_free_space_gb 時的處理。
    # 行為：阻塞任務，避免下載到一半塞滿磁碟。
    if_free_space_below_minimum: "blocked"

    # 單一影片失敗時的處理。
    # 行為：繼續處理其他影片，並把失敗項目寫入 failed-items.json。
    if_single_video_fails: "continue_and_report_failed_item"

    # 下載工具不存在或不可執行時的處理。
    # 行為：阻塞任務，回報缺少 yt-dlp 或 runner 依賴。
    if_downloader_missing: "blocked"
```

---

## 4. 存放路徑變數規則

存放路徑不由對話臨時決定，也不得寫死在程式碼中。Agent 必須依照以下順序處理：

1. 讀取 `storage.STORAGE_PATH_VARIABLES`。
2. 讀取 `storage.active_output_root_variable`，取得正式輸出根目錄變數名稱。
3. 以該變數對應的路徑作為影片成品輸出根目錄。
4. 若該路徑不存在、未掛載或剩餘空間低於 `storage.min_free_space_gb`，依 `failure_policy` 處理。
5. 若 `storage.allow_fallback_output_root` 為 `true`，且 primary 不可用，可以改用 `output_root_fallback`，但必須在 `result.json` 與 `download-report.json` 中明確記錄實際使用路徑。
6. 所有影片檔、info.json、thumbnail 與後續 sidecar metadata，必須依 `storage.output_path_template` 產生目標路徑。

---

## 5. Agent 執行說明

Hermes 建立每日任務時，應依本文件產生任務資料。

建議 task 命名：

```text
TASK-YYYYMMDD-TWITCH-ARCHIVE-NNN
```

建議 task request：

```text
依照 Twitch下載/PI16G001_Hermes_Twitch歸檔Worker設定.md 中的 HERMES_TWITCH_ARCHIVE_VARIABLES，下載 TWITCH_CHANNEL_SOURCES 內啟用來源的新 Twitch VOD，避免重複下載，並產出任務結果摘要。
```

Worker 實際執行時，應使用 manifest 中的變數，不得自行覆寫 Twitch 來源或存放路徑。

---

## 6. 頻道來源填寫規則

`TWITCH_CHANNEL_SOURCES` 由使用者或授權 Agent 維護。

每個來源至少應包含：

```yaml
# Twitch 頻道名稱，用於資料夾、報表與任務摘要。
channel_name: "頻道名稱"

# Twitch 頻道影片頁或指定影片來源 URL。
source_url: "https://www.twitch.tv/頻道名稱/videos"

# 是否啟用此來源；暫停下載時改 false，不要直接刪除。
enabled: true

# 用途、授權或維運備註；不得放密碼、cookie、token 或 secret。
note: "用途或授權備註"
```

若來源暫停下載，應將 `enabled` 改成 `false`，不要直接刪除，除非使用者明確要求。

---

## 7. 設計原則

- Hermes 管任務生命週期。
- PI16G001 worker 管實際執行。
- yt-dlp 只負責下載。
- systemd 只負責啟動與保底，不作為任務真相來源。
- Twitch 來源、排程設定與存放路徑以本文件變數為準。
- 任務狀態與派工真相應寫入本專案自己的 Hermes 狀態資料庫，不依賴對話記憶。
