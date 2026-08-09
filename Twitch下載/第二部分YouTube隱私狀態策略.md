# 第二部分：YouTube 隱私狀態策略

> 適用範圍：`Twitch下載/` 獨立專案。  
> 功能階段：第二部分 YouTube 頻道備份。  
> 決策狀態：已確認。  
> 建立日期：2026-08-09  
> 建立時區：Asia/Taipei

---

## 1. 使用者決策

使用者已確認：

```text
A. YouTube 上傳成功後，影片維持 private 私人狀態。
```

---

## 2. 決策結論

第二部分 YouTube 備份的影片隱私策略如下：

```yaml
PHASE_2_YOUTUBE_PRIVACY_POLICY:
  youtube_privacy_status: "private"
  allow_unlisted_without_policy_update: false
  allow_public_without_policy_update: false
  agent_may_change_privacy_after_upload: false
  auto_update_youtube_video_after_upload: false
```

也就是：

1. Hermes 上傳到 YouTube 的影片必須設為 `private`。
2. Hermes 不得自行設為 `unlisted`。
3. Hermes 不得自行設為 `public`。
4. Hermes 不得在上傳後自行修改影片隱私狀態。
5. 若未來要改成 unlisted 或 public，必須先更新本文件。

---

## 3. manifest 要求

`youtube-backup-manifest.json` 必須包含：

```json
{
  "privacy_status": "private",
  "youtube_privacy_policy": "private_confirmed_by_user",
  "auto_update_youtube_video_after_upload": false
}
```

manifest 不得包含 OAuth token、refresh token、client secret、cookie、password 或其他 secret。

---

## 4. result/report 要求

`youtube-backup-result.json` 與 `youtube-backup-report.json` 必須記錄：

```json
{
  "youtube_privacy_status": "private",
  "youtube_privacy_policy": "private_confirmed_by_user",
  "privacy_changed_after_upload": false
}
```

---

## 5. 禁止行為

Hermes / Agent / Worker / runner 不得：

1. 將第二部分備份影片設為 `public`。
2. 將第二部分備份影片設為 `unlisted`。
3. 在上傳後自動修改 YouTube 隱私狀態。
4. 因上傳失敗而改變隱私設定重試。
5. 因使用者未指定其他隱私狀態而自行猜測。
6. 未更新本文件就變更 YouTube 影片隱私策略。

---

## 6. 已確認事項

- 第二部分輸出目的地是指定 YouTube 頻道。
- 第二部分只處理最近一次任務產生的影片。
- 如果最近一次任務產生多支影片，全部符合條件者都要嘗試備份。
- 若部分成功、部分失敗，成功的照算，失敗的必須通知。
- 部分影片上傳失敗不阻擋後續 Twitch 下載。
- YouTube 上傳成功後，影片必須維持 private 私人狀態。
