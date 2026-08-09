# 第二部分：YouTube 頻道備份功能規格

> 適用範圍：`Twitch下載/` 獨立專案。  
> 功能階段：第二部分。  
> 功能狀態：規格已建立；備份範圍已確認為「最近一次任務產生的影片」。  
> 目的：在進行 Twitch 下載之前，先將最近一次任務產生的影片備份一份到指定 YouTube 頻道中，完成備份驗收後才允許進入後續 Twitch 下載流程。  
> 建立日期：2026-08-09  
> 最近更新：2026-08-09，確認第二部分只備份最近一次任務產生的影片。  
> 建立時區：Asia/Taipei

---

## 1. 結論

本文件定義本專案的第二部分功能：

```text
Twitch 下載前，先將最近一次任務產生的影片備份到指定 YouTube 頻道
```

第二部分不是 Twitch 下載本身。

第二部分的職責是：

1. 找出最近一次任務產生的影片。
2. 驗證影片檔案狀態、metadata、去重狀態與 YouTube 備份資格。
3. 將符合條件的影片上傳到指定 YouTube 頻道。
4. 記錄 YouTube video id、upload 狀態與備份結果。
5. 產生完整 report。
6. 若備份失敗，停止後續 Twitch 下載並通知使用者。

只有當第二部分通過，後續 Twitch 下載才可繼續。

---

## 2. 已確認決策

使用者已確認：

```yaml
PHASE_2_CONFIRMED_DECISIONS:
  youtube_backup_destination: "specified_youtube_channel"
  youtube_backup_selection_mode: "latest_task_generated_videos"
```

意思是：

1. 第二部分匯出的目的地是指定 YouTube 頻道。
2. 第二部分只處理「最近一次任務產生的影片」。
3. 不備份整個來源資料夾。
4. 不使用人工清單。
5. 不備份任意歷史影片。
6. 不由 Hermes 自行搜尋或猜測影片。

---

## 3. 第二部分與 Twitch 下載的關係

第二部分必須在後續 Twitch 下載之前執行。

流程順序：

```text
第一次 Hermes bootstrap / dry-run 通過
  ↓
確認最近一次任務產物
  ↓
第二部分：YouTube 備份最近一次任務產生的影片
  ↓
YouTube 備份成功或最近一次任務沒有產生待備份影片
  ↓
才允許進入後續 Twitch 下載流程
```

若第二部分有待備份影片但備份失敗，Hermes 必須：

1. 停止後續 Twitch 下載。
2. 不得下載新的 Twitch 影片。
3. 不得刪除原始影片。
4. 透過 Hermes 既有 Discord 綁定通知使用者。
5. 回報：

```text
blocked_youtube_backup_failed_before_twitch_download
```

---

## 4. 第二部分不包含什麼

第二部分不包含：

1. Twitch VOD 下載。
2. Twitch chat 下載。
3. clips 下載。
4. highlights 下載。
5. live recording。
6. 自動刪除本機影片。
7. 自動刪除 YouTube 影片。
8. 自行建立 YouTube 頻道。
9. 自行取得或保存 YouTube OAuth secret。
10. 自行公開影片。
11. 自行修改 YouTube 影片標題、描述、隱私設定為未授權值。
12. 掃描整個資料夾並上傳所有影片。
13. 依人工清單上傳影片。
14. 上傳非最近一次任務產生的影片。

---

## 5. 啟用條件

Hermes 啟用第二部分前，必須確認：

```yaml
PHASE_2_YOUTUBE_BACKUP_ENABLEMENT_CHECKLIST:
  first_execution_completed: true
  first_execution_status: "ready_for_channel_sources"
  bootstrap_passed: true
  preflight_passed: true
  runner_exists_and_executable: true
  dry_run_passed: true
  notification_runtime_available: true
  youtube_backup_enabled: true
  youtube_backup_selection_mode: "latest_task_generated_videos"
  latest_task_artifacts_available: true
  youtube_target_channel_configured: true
  youtube_oauth_runtime_available: true
  youtube_oauth_secret_not_in_repository: true
  youtube_upload_archive_available: true
```

只要任一項不成立，Hermes 不得執行 YouTube 備份，也不得進入後續 Twitch 下載。

---

## 6. 第二部分變數

```yaml
PHASE_2_YOUTUBE_BACKUP_VARIABLES:
  # 是否啟用第二部分 YouTube 備份。
  enabled: true

  # 第二部分執行順序。
  # before_twitch_download 表示必須在 Twitch 下載之前完成。
  execution_order: "before_twitch_download"

  # 備份範圍。
  # 使用者已確認：只備份最近一次任務產生的影片。
  youtube_backup_selection_mode: "latest_task_generated_videos"

  # 最近一次任務產物來源。
  # Hermes 必須從自己管理的最新 task artifacts 判斷，不得掃描任意資料夾。
  latest_task_artifact_source: "hermes_latest_task_artifacts"

  # 允許讀取的最近一次任務產物檔案。
  latest_task_artifact_files:
    - "result.json"
    - "download-report.json"
    - "downloaded-items.json"
    - "task-envelope.json"
    - "execution-manifest.json"

  # 是否允許掃描整個來源資料夾。
  # 使用者已選 C，因此不得掃描整個資料夾上傳全部影片。
  recursive_scan_entire_source_root_enabled: false

  # 是否允許人工清單。
  # 使用者已選 C，因此目前不使用人工清單。
  manual_video_list_enabled: false

  # 允許上傳的副檔名。
  allowed_video_extensions:
    - ".mp4"
    - ".mkv"
    - ".mov"
    - ".webm"

  # YouTube 目標頻道識別。
  # 實際值變數化，不得在 repo 中保存 OAuth token 或 refresh token。
  youtube_target_channel_id: null
  youtube_target_channel_label: null
  youtube_oauth_secret_location: "managed_by_hermes_runtime_not_in_repository"

  # 預設上傳隱私。
  # 為避免誤公開，預設 private。
  youtube_default_privacy_status: "private"

  # 是否標記為兒童向內容。
  # 預設不假設內容為兒童向；如實際內容不同，使用者必須更新設定。
  youtube_made_for_kids: false

  # YouTube 備份去重狀態檔。
  youtube_upload_archive_file: "/var/lib/twitch-archiver/youtube-upload-archive.jsonl"

  # YouTube 備份 log 目錄。
  youtube_backup_log_dir: "/var/log/twitch-archiver/youtube-backup"

  # YouTube 備份任務產物根目錄。
  youtube_backup_result_root: "/srv/twitch-worker/results/youtube-backup"

  # 上傳成功後是否刪除本機影片。
  # 本專案目前禁止自動刪除影片。
  delete_local_video_after_upload: false

  # 上傳成功後是否允許修改 YouTube 影片狀態。
  # 預設不允許後續自動修改。
  auto_update_youtube_video_after_upload: false
```

---

## 7. 必讀前置文件

Hermes 執行第二部分前，必須依序讀取：

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

若任一文件缺失、不可讀或互相衝突，Hermes 必須停止並回報：

```text
blocked_missing_or_conflicting_required_docs
```

---

## 8. 最近一次任務影片判斷規則

Hermes 必須從最近一次任務產物判斷待備份影片。

優先讀取順序：

1. `downloaded-items.json`
2. `download-report.json`
3. `result.json`
4. `task-envelope.json`
5. `execution-manifest.json`

Hermes 只能將最近一次任務明確產生的影片列為待備份項目。

最近一次任務影片必須符合：

```yaml
LATEST_TASK_VIDEO_ELIGIBILITY:
  generated_by_latest_task: true
  local_file_exists: true
  local_file_is_video: true
  file_extension_allowed: true
  file_size_greater_than_zero: true
  file_not_still_being_written: true
  not_already_uploaded_to_youtube: true
```

若 Hermes 找不到最近一次任務產物，必須回報：

```text
blocked_latest_task_artifacts_not_found
```

若最近一次任務沒有產生任何待備份影片，第二部分可回報：

```text
succeeded_no_latest_task_videos_to_backup
```

此狀態允許後續 Twitch 下載流程繼續。

---

## 9. 待備份影片篩選規則

Hermes 篩選最近一次任務影片時，必須排除：

1. 不屬於最近一次任務產物的檔案。
2. 副檔名不在 allowlist 的檔案。
3. 檔案大小為 0 的檔案。
4. 最後修改時間仍在變動中的檔案。
5. 已存在於 `youtube_upload_archive_file` 的檔案。
6. 已標示為 upload skipped 的檔案。
7. metadata 不完整且無法生成 YouTube title 的檔案。

若沒有任何待備份影片，第二部分可回報：

```text
succeeded_no_pending_youtube_backup_items
```

此狀態允許後續 Twitch 下載流程繼續。

---

## 10. YouTube 上傳 metadata 規則

Hermes 必須從最近一次任務產物、影片檔案與 sidecar metadata 產生 YouTube metadata。

最低 metadata：

```json
{
  "title": "<VIDEO_TITLE>",
  "description": "Backed up by Hermes from Twitch下載 project.",
  "privacyStatus": "private",
  "madeForKids": false
}
```

規則：

1. 預設隱私必須是 `private`。
2. 若使用者未授權，不得改成 `public` 或 `unlisted`。
3. title 不得包含 token、cookie、password 或其他 secret。
4. description 不得包含本機敏感路徑、secret 或 Discord webhook。
5. tag、playlist、category 若未設定，Hermes 不得自行猜測。

---

## 11. YouTube OAuth 與 secret 規則

YouTube 上傳所需 OAuth、refresh token、client secret 或其他憑證，只能由 Hermes runtime 管理。

不得保存於：

1. GitHub repo。
2. README。
3. execution manifest。
4. result.json。
5. download-report.json。
6. log。
7. Discord 通知。

若 Hermes runtime 沒有可用 YouTube OAuth，必須停止並回報：

```text
blocked_youtube_oauth_runtime_unavailable
```

不得要求 Agent 把 token 寫進文件。

---

## 12. 去重規則

YouTube 備份必須有自己的 upload archive。

預設位置：

```text
/var/lib/twitch-archiver/youtube-upload-archive.jsonl
```

每次成功上傳後，至少記錄：

```json
{
  "local_file_path": "<PATH>",
  "local_file_sha256": "<SHA256>",
  "source_task_id": "<LATEST_TASK_ID>",
  "youtube_video_id": "<YOUTUBE_VIDEO_ID>",
  "uploaded_at": "ISO-8601",
  "privacy_status": "private"
}
```

若同一檔案已存在於 archive，Hermes 不得重複上傳，必須回報：

```text
skipped_already_uploaded_to_youtube
```

---

## 13. 任務流程

第二部分 YouTube 備份流程：

```text
讀取必讀文件
  ↓
確認 phase 2 啟用條件
  ↓
確認備份範圍為 latest_task_generated_videos
  ↓
確認最近一次任務產物可讀
  ↓
確認 YouTube 目標頻道已設定
  ↓
確認 YouTube OAuth runtime 可用
  ↓
從最近一次任務產物取得待備份影片
  ↓
排除已上傳與不合格檔案
  ↓
產生 youtube-backup-manifest.json
  ↓
逐一上傳到指定 YouTube 頻道
  ↓
記錄 youtube video id
  ↓
更新 youtube-upload-archive.jsonl
  ↓
產生 youtube-backup-result.json / youtube-backup-report.json
  ↓
若成功或無待備份影片，允許後續 Twitch 下載
  ↓
若失敗，停止後續 Twitch 下載並通知使用者
```

---

## 14. 任務產物

每次第二部分任務至少產生：

```text
youtube-backup-manifest.json
youtube-backup-result.json
youtube-backup-report.json
youtube-uploaded-items.json
youtube-skipped-items.json
youtube-failed-items.json
logs/youtube-backup.log
```

若任務被阻擋，也必須產生：

```text
youtube-backup-result.json
youtube-backup-report.json
```

不得只留下 stdout 或 terminal log。

---

## 15. youtube-backup-manifest.json 格式

最低格式：

```json
{
  "project": "twitch-archive",
  "phase": "phase_2_youtube_backup_before_twitch_download",
  "task_id": "YOUTUBE-BACKUP-BEFORE-TWITCH-YYYYMMDD-NNN",
  "worker_id": "PI16G001",
  "youtube_backup_selection_mode": "latest_task_generated_videos",
  "source_task_id": "<LATEST_TASK_ID>",
  "target_channel_id_configured": true,
  "privacy_status": "private",
  "made_for_kids": false,
  "delete_local_video_after_upload": false,
  "auto_update_youtube_video_after_upload": false
}
```

manifest 不得包含 OAuth token、client secret、refresh token、cookie 或 password。

---

## 16. youtube-backup-result.json 格式

最低格式：

```json
{
  "project": "twitch-archive",
  "phase": "phase_2_youtube_backup_before_twitch_download",
  "task_id": "YOUTUBE-BACKUP-BEFORE-TWITCH-YYYYMMDD-NNN",
  "source_task_id": "<LATEST_TASK_ID>",
  "worker_id": "PI16G001",
  "status": "succeeded | succeeded_no_latest_task_videos_to_backup | blocked | failed",
  "started_at": "ISO-8601",
  "finished_at": "ISO-8601",
  "youtube_backup_selection_mode": "latest_task_generated_videos",
  "videos_discovered_from_latest_task": 0,
  "videos_uploaded": 0,
  "videos_skipped": 0,
  "videos_failed": 0,
  "local_videos_deleted": 0,
  "twitch_download_allowed_after_backup": false,
  "notification_sent": false,
  "notification_channel": "discord_via_hermes_existing_binding"
}
```

---

## 17. 成功與失敗判定

以下狀態可視為第二部分成功：

```text
succeeded
succeeded_no_latest_task_videos_to_backup
succeeded_no_pending_youtube_backup_items
```

這些狀態允許後續 Twitch 下載流程繼續。

以下狀態必須阻擋後續 Twitch 下載：

```text
blocked_latest_task_artifacts_not_found
blocked_youtube_oauth_runtime_unavailable
blocked_youtube_target_channel_not_configured
blocked_youtube_backup_failed_before_twitch_download
failed_youtube_upload_error
```

---

## 18. 通知規則

以下情況必須透過 Hermes 既有 Discord 綁定通知使用者：

1. 找不到最近一次任務產物。
2. YouTube OAuth runtime 不可用。
3. 目標 YouTube 頻道未設定。
4. 有待備份影片但上傳失敗。
5. 上傳後無法取得 YouTube video id。
6. YouTube upload archive 無法寫入。
7. 任務失敗導致後續 Twitch 下載被阻擋。

成功摘要可依 Hermes runtime 設定發送。

通知不得包含 token、client secret、refresh token、cookie、password 或本機敏感路徑。

---

## 19. 給 Hermes 的第二部分啟動指令範本

當 Hermes 已完成第一次 bootstrap / dry-run，且使用者已設定 YouTube 目標頻道與 Hermes runtime OAuth 後，可交給 Hermes：

```text
請執行 Twitch下載 第二部分 YouTube 頻道備份功能。

請先讀取：
Twitch下載/第二部分YouTube頻道備份功能規格.md

第二部分的目標是在進行 Twitch 下載之前，先將最近一次任務產生的影片備份一份到指定 YouTube 頻道。

請驗證最近一次任務產物、YouTube 目標頻道與 Hermes runtime OAuth 是否可用。

若最近一次任務有產生待備份影片，請先備份到 YouTube，寫入 youtube upload archive，產生 report。

只有在 YouTube 備份成功，或最近一次任務沒有待備份影片時，才允許進入後續 Twitch 下載流程。

不得保存 YouTube token / refresh token / client secret，不得自動刪除本機影片，不得自行公開影片，不得掃描整個來源資料夾上傳影片。
```

---

## 20. 禁止行為

Hermes / Agent / Worker / runner 在第二部分中不得：

1. 自行猜測 YouTube 目標頻道。
2. 自行建立 YouTube 頻道。
3. 自行取得或保存 YouTube OAuth secret。
4. 自行把影片設成 public 或 unlisted。
5. 自行刪除本機影片。
6. 自行刪除 YouTube 影片。
7. 掃描整個來源資料夾並上傳所有影片。
8. 使用人工清單上傳影片。
9. 上傳不是最近一次任務產生的影片。
10. 上傳疑似仍在寫入中的影片。
11. 在 report、manifest、log 或 Discord 通知中寫入 secret。
12. 在 YouTube 備份失敗後繼續 Twitch 下載。

---

## 21. 最終判定

第二部分完成目標是：

```text
Hermes 在進行 Twitch 下載之前，先把最近一次任務產生的影片備份一份到指定 YouTube 頻道，完成去重、上傳、YouTube video id 記錄與 report 產出；若備份失敗，停止後續 Twitch 下載並通知使用者。
```

第二部分不授權 Hermes 下載 Twitch、公開影片、刪除影片、掃描整個資料夾上傳影片、使用人工清單上傳影片，或保存任何 YouTube / Discord / Twitch secret。
