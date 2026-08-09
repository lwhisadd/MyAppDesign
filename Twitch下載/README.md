# Twitch下載

> 人類操作入口。  
> 本目錄是一個獨立專案：在 Raspberry Pi 5 `PI16G001` 上，由 Hermes agent 管理每日 Twitch VOD 定時下載。  
> Humans 先讀這份 README；Hermes / Agent 第一份要讀 `Twitch下載/Hermes交接入口.md`。

---

## 1. 先看結論

目前文件已經足夠讓 Hermes 理解整個專案、完成第一次 bootstrap、preflight、runner 產生與 dry-run。

但目前還不能正式下載 Twitch 影片，原因是：

```text
TWITCH_CHANNEL_SOURCES 目前仍是空清單
```

因此目前正確狀態是：

```yaml
project_status:
  documentation: "ready"
  hermes_first_execution: "ready_for_bootstrap_and_dry_run"
  phase_2_formal_download_spec: "ready"
  real_download: "blocked_until_channel_sources_configured"
  channel_sources: "empty_by_design"
```

也就是：

1. 可以把本專案交給 Hermes。
2. Hermes 可以先做實機 bootstrap 與 dry-run。
3. Hermes 不可以猜測 Twitch 頻道。
4. Hermes 不可以在來源清單空白時正式下載影片。
5. 等 Hermes 回報 `ready_for_channel_sources` 後，再由使用者填入 Twitch 來源。
6. 來源填入並驗證通過後，第二部分正式每日下載功能以 `第二部分正式每日下載功能規格.md` 為準。

---

## 2. 人類下一步要怎麼做

### Step 1：把這段話交給 Hermes

```text
請先讀取：

Twitch下載/Hermes交接入口.md

這份文件是本專案的第一入口。讀完後，請依照文件中的讀取順序讀取其他必讀文件，並依照：

Twitch下載/首次Hermes執行任務票.md

執行第一次 bootstrap、preflight、runner 產生與 dry-run。

注意：目前 TWITCH_CHANNEL_SOURCES 尚未填入，因此不得正式下載 Twitch 影片。完成後請只回報 ready_for_channel_sources 或 blocked_with_reason。
```

### Step 2：等 Hermes 第一次實機任務結果

Hermes 第一次應只回報兩種結果之一：

```text
ready_for_channel_sources
```

或：

```text
blocked_with_reason
```

如果回報 `ready_for_channel_sources`，代表：

1. PI16G001 preflight 通過。
2. 必要套件已安裝或已存在。
3. 目錄已建立或確認。
4. runner 已產生且可執行。
5. dry-run 通過。
6. 通知能力已檢查。
7. 還沒有正式下載任何 Twitch 影片。

### Step 3：填入 Twitch 來源

等 Hermes 回報 `ready_for_channel_sources` 後，再填入實際 Twitch 來源。

來源要填在：

```text
Twitch下載/PI16G001_Hermes_Twitch歸檔Worker設定.md
```

變數位置：

```yaml
TWITCH_CHANNEL_SOURCES
```

格式規則請看：

```text
Twitch下載/頻道來源維護規格.md
```

來源範例格式如下：

```yaml
TWITCH_CHANNEL_SOURCES:
  - source_id: "example_channel_vods"
    channel_name: "example_channel"
    source_url: "https://www.twitch.tv/example_channel/videos"
    source_type: "channel_videos"
    enabled: true
    authorization_status: "user_confirmed"
    note: "使用者指定的 Twitch 頻道影片來源"
```

### Step 4：來源填好後才允許正式下載

正式下載前，Hermes 必須確認：

```yaml
ready_for_real_download:
  bootstrap_passed: true
  preflight_passed: true
  runner_ready: true
  dry_run_passed: true
  notification_runtime_available: true
  output_root_available: true
  free_space_above_1gb: true
  channel_sources_non_empty: true
  all_enabled_sources_user_confirmed: true
  no_secret_in_sources: true
```

只要其中任何一項不通過，Hermes 不得正式下載。

### Step 5：正式下載依第二部分文件執行

來源填好且驗證通過後，正式每日下載流程以這份文件為準：

```text
Twitch下載/第二部分正式每日下載功能規格.md
```

這份文件定義：每日 task id、正式 manifest、yt-dlp 執行規則、download archive 去重、1080p / 720p 畫質處理、低磁碟停止、報告格式與 Discord 通知規則。

---

## 3. Hermes 要先讀哪份文件

Hermes / Agent 收到本專案後，第一份要讀：

```text
Twitch下載/Hermes交接入口.md
```

這份文件會告訴 Hermes：

1. 現在專案狀態。
2. 要依什麼順序讀其他文件。
3. 哪些事可以自主做。
4. 哪些事必須停止並通知使用者。
5. 來源清單空白時不得正式下載。
6. 第一次實機作業要依 `首次Hermes執行任務票.md` 執行。
7. 來源填入並驗證後，正式下載要依 `第二部分正式每日下載功能規格.md` 執行。

---

## 4. Humans 要看哪份文件

人類通常只需要看這份 README。

要改特定設定時，再看對應文件：

| 你想做的事 | 要看哪份文件 |
|---|---|
| 把專案交給 Hermes | `Hermes交接入口.md` |
| 第一次讓 Hermes 跑實機 bootstrap / dry-run | `首次Hermes執行任務票.md` |
| 設定 Twitch 頻道來源 | `頻道來源維護規格.md`、`PI16G001_Hermes_Twitch歸檔Worker設定.md` |
| 讓 Hermes 執行正式每日下載 | `第二部分正式每日下載功能規格.md` |
| 改下載畫質策略 | `下載畫質設定.md` |
| 改是否保存聊天紀錄 | `聊天紀錄保存策略.md` |
| 改影片保留或刪除策略 | `影片保留策略.md` |
| 改安裝、runner、dry-run 或驗收流程 | `Hermes自主佈建與執行規格.md` |
| 查完整任務變數、排程、路徑、通知設定 | `PI16G001_Hermes_Twitch歸檔Worker設定.md` |

---

## 5. 目前文件清單

| 文件 | 用途 |
|------|------|
| `README.md` | 人類操作入口；說明目前狀態、下一步、交給 Hermes 的指令與正式下載前條件 |
| `Hermes交接入口.md` | Hermes / Agent 第一入口；定義讀取順序、目前狀態、允許作業、停止條件與正式下載前檢查清單 |
| `首次Hermes執行任務票.md` | Hermes 第一次實機任務；只允許 bootstrap、preflight、runner 產生、dry-run 與回報，不允許正式下載 |
| `第二部分正式每日下載功能規格.md` | 定義來源填入並驗證通過後的正式每日 Twitch VOD 下載流程、去重、畫質處理、任務產物、報告與通知規則 |
| `PI16G001_Hermes_Twitch歸檔Worker設定.md` | 主設定檔；保存 Twitch 下載任務變數、排程、worker、儲存路徑、通知與失敗策略 |
| `頻道來源維護規格.md` | 定義 `TWITCH_CHANNEL_SOURCES` 的格式、維護方式、驗證規則、空清單處理與禁止猜測來源規則 |
| `下載畫質設定.md` | 定義畫質策略：優先 1080p，fallback 到 720p；若都沒有則通知並結束當天作業 |
| `聊天紀錄保存策略.md` | 定義聊天紀錄策略：目前只下載影片，不保存 Twitch 聊天紀錄 |
| `影片保留策略.md` | 定義影片保留策略：永久保存，除非使用者手動刪除；不得自動刪除影片 |
| `Hermes自主佈建與執行規格.md` | 定義 Hermes 自主 preflight、套件安裝、目錄建立、runner 產生、每日任務、下載執行、任務產物與 dry-run 驗收流程 |

---

## 6. Agent / Hermes 必讀順序

所有 Agent 在規劃、修改、派送、佈建或執行本專案任務前，必須依序讀取：

1. `Twitch下載/Hermes交接入口.md`
2. `Twitch下載/README.md`
3. `Twitch下載/PI16G001_Hermes_Twitch歸檔Worker設定.md`
4. `Twitch下載/頻道來源維護規格.md`
5. `Twitch下載/下載畫質設定.md`
6. `Twitch下載/聊天紀錄保存策略.md`
7. `Twitch下載/影片保留策略.md`
8. `Twitch下載/Hermes自主佈建與執行規格.md`
9. `Twitch下載/首次Hermes執行任務票.md`
10. `Twitch下載/第二部分正式每日下載功能規格.md`

不得只依賴對話記憶、README 摘要或其他根目錄文件。

---

## 7. 已確認的專案決策

```yaml
CONFIRMED_DECISIONS:
  project: "twitch-archive"
  context_root: "Twitch下載"
  worker: "PI16G001"
  managed_by: "Hermes agent"
  recurrence: "daily"
  timezone: "Asia/Taipei"

  download_scope:
    vods: true
    highlights: false
    clips: false
    live_recording: false

  channel_sources:
    truth_source: "TWITCH_CHANNEL_SOURCES"
    current_status: "empty_by_design"
    agent_may_guess_sources: false
    if_empty: "requires_user_input_channel_sources_empty"

  phase_2_formal_download:
    spec_file: "第二部分正式每日下載功能規格.md"
    enabled_only_after_channel_sources_validated: true
    real_download_before_sources_configured: false

  quality:
    primary: "1080p"
    fallback: "720p"
    if_1080p_and_720p_unavailable: "notify_user_and_end_daily_job"
    allow_below_720p: false

  chat_archive:
    enabled: false

  video_retention:
    mode: "keep_forever_until_user_deletes"
    auto_delete: false

  disk:
    min_free_space_gb: 1
    if_below_minimum: "notify_user_via_discord_and_block_task"

  notification:
    channel: "discord_via_hermes_existing_binding"
    secrets_in_repository_allowed: false
```

---

## 8. 目前絕對不能做的事

Hermes / Agent / Worker / runner 不得：

1. 在 `TWITCH_CHANNEL_SOURCES` 空白時正式下載 Twitch 影片。
2. 猜測、搜尋或自行新增 Twitch 頻道來源。
3. 把頻道、路徑、排程、畫質、通知寫死到 runner、prompt、systemd unit 或 manifest template。
4. 下載 Twitch 聊天紀錄。
5. 自動刪除已下載影片。
6. 自行降低到 480p 或更低畫質。
7. 保存 Discord webhook、bot token、Twitch OAuth token、cookie、密碼或其他 secret。
8. 混用 `多機協作/`、`前台選型/`、`討論3/` 等其他根目錄的決策。
9. 安裝 allowlist 以外的套件。
10. 在未通過 dry-run 前宣稱可正式下載。
11. 在未讀取 `第二部分正式每日下載功能規格.md` 前執行正式每日下載。

---

## 9. 第一次 Hermes 實機任務做什麼

第一次實機任務只做：

```text
讀取必讀文件
  ↓
確認來源清單目前可保持空白
  ↓
PI16G001 preflight
  ↓
安裝或確認 allowlist 套件
  ↓
建立或確認 managed directories
  ↓
產生或確認 /srv/twitch-worker/bin/run-twitch-archive
  ↓
產生 dry-run manifest
  ↓
執行 dry-run
  ↓
產生 bootstrap-report / dry-run-report
  ↓
回報 ready_for_channel_sources 或 blocked_with_reason
```

第一次任務不處理：

1. 實際 Twitch 頻道來源填寫。
2. 正式 Twitch 影片下載。
3. 聊天紀錄下載。
4. 已下載影片刪除。
5. live recording。
6. clips 下載。
7. highlights 下載。

---

## 10. 什麼時候才算可以正式下載

只有同時符合以下條件，Hermes 才能正式下載：

1. 所有必讀文件已讀取。
2. 文件沒有互相衝突。
3. bootstrap 通過。
4. preflight 通過。
5. runner 已存在且可執行。
6. dry-run 通過。
7. Hermes 既有 Discord 通知能力可用。
8. output root 可用。
9. 剩餘空間高於 1GB。
10. `TWITCH_CHANNEL_SOURCES` 不為空。
11. 所有啟用來源都是 `authorization_status: "user_confirmed"`。
12. 來源中沒有 secret、token、cookie 或 password。
13. Hermes 已讀取 `第二部分正式每日下載功能規格.md`。

正式每日下載的實際流程、manifest、task artifacts、報告與通知規則，以 `第二部分正式每日下載功能規格.md` 為準。

---

## 11. Context 邊界

本目錄是獨立專案 context。

Agent 處理本目錄時，必須遵守：

1. 不得自動引用 `多機協作/` 的 Hermes、Codex、DB、worker 或部署決策。
2. 不得自動引用 `前台選型/`、`討論3/` 或其他根目錄的技術決策。
3. 若需要參考其他目錄，只能作為外部參考，且必須明確標注來源。
4. 本目錄內的文件優先於其他根目錄文件。
5. 若本 README 與本目錄內其他文件衝突，以本目錄內較新的明確決策文件為準。

---

## 12. 給人類的最短操作摘要

```text
1. 把 Twitch下載/Hermes交接入口.md 交給 Hermes。
2. 要 Hermes 依 Twitch下載/首次Hermes執行任務票.md 跑第一次 bootstrap + dry-run。
3. 等 Hermes 回報 ready_for_channel_sources。
4. 再到 PI16G001_Hermes_Twitch歸檔Worker設定.md 填 TWITCH_CHANNEL_SOURCES。
5. 確認來源格式符合 頻道來源維護規格.md。
6. 來源填好且驗證通過後，讓 Hermes 依 第二部分正式每日下載功能規格.md 執行正式每日下載。
```
