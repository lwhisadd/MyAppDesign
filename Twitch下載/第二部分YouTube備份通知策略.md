# 第二部分：YouTube 備份通知策略

> 適用範圍：`Twitch下載/` 獨立專案。  
> 功能階段：第二部分 YouTube 頻道備份。  
> 決策狀態：已確認。  
> 建立日期：2026-08-09  
> 建立時區：Asia/Taipei

---

## 1. 使用者決策

使用者已確認：

```text
A. YouTube 備份成功與失敗都通知。
```

---

## 2. 決策結論

第二部分 YouTube 備份的通知策略如下：

```yaml
PHASE_2_YOUTUBE_BACKUP_NOTIFICATION_POLICY:
  notify_on_success: true
  notify_on_failure: true
  notify_on_partial_failure: true
  notify_on_no_pending_items: true
  notification_channel: "discord_via_hermes_existing_binding"
  notification_secret_location: "managed_by_hermes_runtime_not_in_repository"
  secrets_in_repository_allowed: false
```

也就是：

1. YouTube 備份全部成功時要通知使用者。
2. YouTube 備份全部失敗時要通知使用者。
3. YouTube 備份部分成功、部分失敗時要通知使用者。
4. 最近一次任務沒有待備份影片時也要通知使用者。
5. 通知管道使用 Hermes 既有 Discord 綁定。
6. 不得在 repo、manifest、report、log 或通知內容中保存 Discord webhook、bot token、YouTube OAuth token、refresh token、client secret、cookie、password 或其他 secret。

---

## 3. 通知事件

Hermes 必須在以下事件通知使用者：

```yaml
PHASE_2_NOTIFICATION_EVENTS:
  youtube_backup_succeeded: true
  youtube_backup_succeeded_no_pending_items: true
  youtube_backup_succeeded_with_upload_failures: true
  youtube_backup_failed: true
  youtube_backup_blocked_by_phase_level_error: true
```

---

## 4. 成功通知內容

YouTube 備份成功通知至少包含：

```json
{
  "event": "youtube_backup_succeeded",
  "project": "twitch-archive",
  "phase": "phase_2_youtube_backup_before_twitch_download",
  "worker_id": "PI16G001",
  "task_id": "<YOUTUBE_BACKUP_TASK_ID>",
  "source_task_id": "<LATEST_TASK_ID>",
  "videos_uploaded": 0,
  "videos_failed": 0,
  "youtube_privacy_status": "private",
  "twitch_download_allowed_after_backup": true
}
```

---

## 5. 部分失敗通知內容

YouTube 備份部分成功、部分失敗通知至少包含：

```json
{
  "event": "youtube_backup_succeeded_with_upload_failures",
  "project": "twitch-archive",
  "phase": "phase_2_youtube_backup_before_twitch_download",
  "worker_id": "PI16G001",
  "task_id": "<YOUTUBE_BACKUP_TASK_ID>",
  "source_task_id": "<LATEST_TASK_ID>",
  "videos_uploaded": 0,
  "videos_failed": 0,
  "failed_uploads_report_path": "<REPORT_PATH>",
  "twitch_download_allowed_after_backup": true
}
```

部分失敗通知不得包含 OAuth token、refresh token、client secret、cookie、password、Discord webhook 或本機敏感路徑。

---

## 6. 失敗通知內容

YouTube 備份失敗或被 phase-level blocker 阻擋時，通知至少包含：

```json
{
  "event": "youtube_backup_failed_or_blocked",
  "project": "twitch-archive",
  "phase": "phase_2_youtube_backup_before_twitch_download",
  "worker_id": "PI16G001",
  "task_id": "<YOUTUBE_BACKUP_TASK_ID>",
  "blocked_reason": "<REASON_CODE>",
  "twitch_download_allowed_after_backup": false
}
```

---

## 7. 無待備份影片通知內容

若最近一次任務沒有待備份影片，Hermes 仍需通知使用者。

通知至少包含：

```json
{
  "event": "youtube_backup_no_pending_items",
  "project": "twitch-archive",
  "phase": "phase_2_youtube_backup_before_twitch_download",
  "worker_id": "PI16G001",
  "task_id": "<YOUTUBE_BACKUP_TASK_ID>",
  "source_task_id": "<LATEST_TASK_ID>",
  "videos_uploaded": 0,
  "videos_failed": 0,
  "twitch_download_allowed_after_backup": true
}
```

---

## 8. result/report 要求

`youtube-backup-result.json` 與 `youtube-backup-report.json` 必須記錄：

```json
{
  "notify_on_success": true,
  "notify_on_failure": true,
  "notify_on_partial_failure": true,
  "notify_on_no_pending_items": true,
  "notification_channel": "discord_via_hermes_existing_binding",
  "notification_sent": true
}
```

若通知失敗，必須記錄：

```text
notification_failed
```

若備份本身成功但通知失敗，Hermes 必須在 report 中標記通知失敗；是否繼續後續 Twitch 下載由 phase-level blocker 規則判定。若 Hermes runtime 判定通知能力是必要前置能力，則應阻擋並回報通知 runtime 不可用。

---

## 9. 禁止行為

Hermes / Agent / Worker / runner 不得：

1. 成功時完全不通知。
2. 失敗時完全不通知。
3. 部分失敗時只寫 report、不通知。
4. 無待備份影片時完全不通知。
5. 在通知內容中寫入 Discord webhook。
6. 在通知內容中寫入 YouTube OAuth token、refresh token、client secret、cookie、password 或其他 secret。
7. 因通知格式不足而自行改變第二部分備份策略。
8. 未更新本文件就改變通知策略。

---

## 10. 已確認事項

- 第二部分輸出目的地是指定 YouTube 頻道。
- 第二部分只處理最近一次任務產生的影片。
- 如果最近一次任務產生多支影片，全部符合條件者都要嘗試備份。
- 若部分成功、部分失敗，成功的照算，失敗的必須通知。
- 部分影片上傳失敗不阻擋後續 Twitch 下載。
- YouTube 上傳成功後，影片必須維持 private 私人狀態。
- YouTube 備份影片標題必須沿用原影片標題。
- YouTube 備份影片描述必須使用原描述或 metadata，並附加固定備份說明。
- YouTube 備份影片不加入 playlist。
- YouTube 備份成功與失敗都必須通知使用者。
