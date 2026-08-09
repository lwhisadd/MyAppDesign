# 第二部分：YouTube 標題策略

> 適用範圍：`Twitch下載/` 獨立專案。  
> 功能階段：第二部分 YouTube 頻道備份。  
> 決策狀態：已確認。  
> 建立日期：2026-08-09  
> 建立時區：Asia/Taipei

---

## 1. 使用者決策

使用者已確認：

```text
A. YouTube 備份影片的標題沿用原影片標題。
```

---

## 2. 決策結論

第二部分 YouTube 備份的標題策略如下：

```yaml
PHASE_2_YOUTUBE_TITLE_POLICY:
  youtube_title_source: "original_video_title"
  add_date_prefix: false
  add_twitch_channel_prefix: false
  agent_may_rewrite_title: false
  agent_may_translate_title: false
  agent_may_append_metadata_to_title: false
```

也就是：

1. YouTube 標題必須沿用原影片標題。
2. Hermes 不得自行加日期前綴。
3. Hermes 不得自行加 Twitch 頻道名稱前綴。
4. Hermes 不得自行改寫、翻譯或摘要標題。
5. Hermes 不得自行把解析度、任務 ID、日期、頻道名或其他 metadata 加到標題中。
6. 若未來要改標題格式，必須先更新本文件。

---

## 3. 原影片標題來源

Hermes 取得原影片標題時，應依序使用：

1. 最近一次任務產物中的影片 title 欄位。
2. 該影片對應的 `info.json` 或 sidecar metadata。
3. runner 產出的 `downloaded-items.json` title 欄位。
4. 若以上都不存在，才可使用不含副檔名的檔名作為 fallback。

若使用 fallback 檔名作標題，必須在 report 中記錄：

```text
title_fallback_to_filename
```

---

## 4. manifest 要求

`youtube-backup-manifest.json` 每支影片至少應包含：

```json
{
  "local_file_path": "<PATH>",
  "original_video_title": "<ORIGINAL_VIDEO_TITLE>",
  "youtube_title": "<ORIGINAL_VIDEO_TITLE>",
  "youtube_title_policy": "original_video_title"
}
```

manifest 不得包含 OAuth token、refresh token、client secret、cookie、password 或其他 secret。

---

## 5. report 要求

`youtube-backup-report.json` 必須記錄：

```json
{
  "youtube_title_policy": "original_video_title",
  "titles_rewritten_by_agent": 0,
  "titles_with_date_prefix": 0,
  "titles_with_channel_prefix": 0
}
```

---

## 6. 禁止行為

Hermes / Agent / Worker / runner 不得：

1. 自行加上日期前綴。
2. 自行加上 Twitch 頻道名稱前綴。
3. 自行改寫標題。
4. 自行翻譯標題。
5. 自行縮短標題。
6. 自行把任務 ID、解析度、下載日期、備份日期加到標題。
7. 因 YouTube 上傳失敗而改變標題重試。
8. 未更新本文件就改變 YouTube 標題策略。

---

## 7. 已確認事項

- 第二部分輸出目的地是指定 YouTube 頻道。
- 第二部分只處理最近一次任務產生的影片。
- 如果最近一次任務產生多支影片，全部符合條件者都要嘗試備份。
- 若部分成功、部分失敗，成功的照算，失敗的必須通知。
- 部分影片上傳失敗不阻擋後續 Twitch 下載。
- YouTube 上傳成功後，影片必須維持 private 私人狀態。
- YouTube 備份影片標題必須沿用原影片標題。
