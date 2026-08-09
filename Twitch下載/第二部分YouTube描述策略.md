# 第二部分：YouTube 描述策略

> 適用範圍：`Twitch下載/` 獨立專案。  
> 功能階段：第二部分 YouTube 頻道備份。  
> 決策狀態：已確認。  
> 建立日期：2026-08-09  
> 建立時區：Asia/Taipei

---

## 1. 使用者決策

使用者已確認：

```text
C. YouTube 影片描述使用「原描述 + 固定備份說明」。
```

---

## 2. 決策結論

第二部分 YouTube 備份的描述策略如下：

```yaml
PHASE_2_YOUTUBE_DESCRIPTION_POLICY:
  youtube_description_mode: "original_description_plus_backup_notice"
  use_original_description_or_metadata: true
  append_fixed_backup_notice: true
  allow_description_empty_without_metadata: false
  allow_fixed_notice_only_when_original_missing: true
  agent_may_rewrite_original_description: false
  agent_may_translate_original_description: false
```

也就是：

1. YouTube 描述應優先沿用原影片描述或 metadata。
2. Hermes 必須在原描述後面附加固定備份說明。
3. Hermes 不得只使用固定描述取代原描述。
4. Hermes 不得自行改寫或翻譯原描述。
5. 若原描述或 metadata 不存在，Hermes 可以只使用固定備份說明，但必須在 report 中記錄。
6. 若未來要改描述格式，必須先更新本文件。

---

## 3. 原描述來源

Hermes 取得原描述時，應依序使用：

1. 最近一次任務產物中的影片 description 欄位。
2. 該影片對應的 `info.json` 或 sidecar metadata。
3. runner 產出的 `downloaded-items.json` description 欄位。
4. 若以上都不存在，使用空字串，並只附加固定備份說明。

若沒有原描述或 metadata，必須在 report 中記錄：

```text
description_fallback_to_backup_notice_only
```

---

## 4. 固定備份說明

固定備份說明必須附加在原描述後方。

建議格式：

```text

---
Backed up by Hermes for the Twitch下載 project.
Original video metadata is preserved when available.
```

固定備份說明不得包含：

1. OAuth token。
2. refresh token。
3. client secret。
4. Discord webhook。
5. cookie。
6. password。
7. 本機敏感路徑。

---

## 5. manifest 要求

`youtube-backup-manifest.json` 每支影片至少應包含：

```json
{
  "local_file_path": "<PATH>",
  "youtube_description_mode": "original_description_plus_backup_notice",
  "original_description_available": true,
  "backup_notice_appended": true
}
```

manifest 不得包含 OAuth token、refresh token、client secret、cookie、password 或其他 secret。

---

## 6. report 要求

`youtube-backup-report.json` 必須記錄：

```json
{
  "youtube_description_policy": "original_description_plus_backup_notice",
  "descriptions_rewritten_by_agent": 0,
  "descriptions_translated_by_agent": 0,
  "descriptions_with_backup_notice_appended": 0,
  "descriptions_fallback_to_backup_notice_only": 0
}
```

---

## 7. 禁止行為

Hermes / Agent / Worker / runner 不得：

1. 自行改寫原描述。
2. 自行翻譯原描述。
3. 自行刪除原描述。
4. 只使用固定描述覆蓋原描述，除非原描述不存在。
5. 將 token、cookie、password、client secret、Discord webhook 或本機敏感路徑寫入描述。
6. 因 YouTube 上傳失敗而改變描述策略重試。
7. 未更新本文件就改變 YouTube 描述策略。

---

## 8. 已確認事項

- 第二部分輸出目的地是指定 YouTube 頻道。
- 第二部分只處理最近一次任務產生的影片。
- 如果最近一次任務產生多支影片，全部符合條件者都要嘗試備份。
- 若部分成功、部分失敗，成功的照算，失敗的必須通知。
- 部分影片上傳失敗不阻擋後續 Twitch 下載。
- YouTube 上傳成功後，影片必須維持 private 私人狀態。
- YouTube 備份影片標題必須沿用原影片標題。
- YouTube 備份影片描述必須使用原描述或 metadata，並附加固定備份說明。
