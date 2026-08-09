# 第二部分：YouTube 播放清單策略

> 適用範圍：`Twitch下載/` 獨立專案。  
> 功能階段：第二部分 YouTube 頻道備份。  
> 決策狀態：已確認。  
> 建立日期：2026-08-09  
> 建立時區：Asia/Taipei

---

## 1. 使用者決策

使用者已確認：

```text
A. YouTube 備份影片不加入 playlist。
```

---

## 2. 決策結論

第二部分 YouTube 備份的播放清單策略如下：

```yaml
PHASE_2_YOUTUBE_PLAYLIST_POLICY:
  add_to_playlist: false
  playlist_id: null
  playlist_label: null
  agent_may_create_playlist: false
  agent_may_choose_playlist: false
  agent_may_add_to_existing_playlist_without_policy_update: false
```

也就是：

1. Hermes 上傳第二部分備份影片後，不得加入 YouTube playlist。
2. Hermes 不得自行建立 playlist。
3. Hermes 不得自行選擇既有 playlist。
4. Hermes 不得因影片來源、頻道名或日期自動分 playlist。
5. 若未來要加入指定 playlist，必須先更新本文件。

---

## 3. manifest 要求

`youtube-backup-manifest.json` 必須包含：

```json
{
  "add_to_playlist": false,
  "playlist_policy": "no_playlist_confirmed_by_user",
  "playlist_id": null
}
```

manifest 不得包含 OAuth token、refresh token、client secret、cookie、password 或其他 secret。

---

## 4. result/report 要求

`youtube-backup-result.json` 與 `youtube-backup-report.json` 必須記錄：

```json
{
  "add_to_playlist": false,
  "playlist_policy": "no_playlist_confirmed_by_user",
  "videos_added_to_playlist": 0
}
```

---

## 5. 禁止行為

Hermes / Agent / Worker / runner 不得：

1. 自行建立 YouTube playlist。
2. 自行把備份影片加入既有 playlist。
3. 根據日期自動建立 playlist。
4. 根據 Twitch 頻道名稱自動建立 playlist。
5. 根據任務 ID 自動建立 playlist。
6. 因使用者未指定 playlist 而自行猜測。
7. 未更新本文件就改變 playlist 策略。

---

## 6. 已確認事項

- 第二部分輸出目的地是指定 YouTube 頻道。
- 第二部分只處理最近一次任務產生的影片。
- 如果最近一次任務產生多支影片，全部符合條件者都要嘗試備份。
- 若部分成功、部分失敗，成功的照算，失敗的必須通知。
- 部分影片上傳失敗不阻擋後續 Twitch 下載。
- YouTube 上傳成功後，影片必須維持 private 私人狀態。
- YouTube 備份影片標題必須沿用原影片標題。
- YouTube 備份影片描述必須使用原描述或 metadata，並附加固定備份說明。
- YouTube 備份影片不加入 playlist。
