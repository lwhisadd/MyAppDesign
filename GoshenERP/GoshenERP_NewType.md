# Skyvern + Web ERP SaaS 架構整理

## 文件目的

本文件整理目前已確認的技術選型、系統邊界、操作流程、資料儲存策略、授權注意事項與後續實作要點，供後續 agent、架構設計人員與開發者參考。Skyvern 適合被放在內部自動化層，透過 REST API、Python SDK 或 TypeScript SDK 由自家系統呼叫，而不是作為外部客戶直接登入的前台產品。

## 專案定位

目標產品是「給外部客戶登入的 SaaS」，但客戶登入的是自家前台，而不是 Skyvern 本身。Skyvern 在此架構中的角色是內部 browser automation engine，負責登入 Web ERP、執行查詢、擷取資料、下載報表與回傳結構化結果。

既有 Web ERP 已有完整 MySQL 在運行，因此 ERP 的業務資料、權限、交易、報表與選單顯示邏輯仍以 ERP/MySQL 為單一真實來源；Skyvern 只管理其自動化執行所需的 metadata 與產物，不取代 ERP 主資料庫。

## 已確認的核心決策

### 1. 前台與自動化層分離

外部客戶只登入自家 SaaS，所有自然語言查詢請求都先進入自家 API/BFF，再由後端呼叫 Skyvern 的 REST API 或 SDK 執行自動化流程。

這種切法可避免直接把 AGPL-3.0 的 Skyvern UI 對外開放，同時也讓帳號、權限、審計、配額、計費與產品體驗由自家系統掌控。

### 2. 使用者以本人 ERP 身份操作

每位使用者都持有唯一 ERP 帳號，因此 Skyvern 應以該使用者自己的 ERP 憑證或已驗證 session 進入 ERP，而不是以共用高權限帳號代操作所有人。

此模式能與 ERP 原生權限控管對齊；若某個選單或功能因權限不足而不顯示，Skyvern 在同一登入身份下通常也不會自然取得該功能範圍。

### 3. ERP MySQL 繼續作為主資料來源

ERP 既有 MySQL 保留不動，繼續承擔使用者、角色、權限、訂單、庫存、交易與報表資料的真實來源角色。Skyvern 層只記錄任務、Session、Credential 映射、Artifacts、執行結果與審計資訊。

### 4. 自動化能力要受控

前台不應直接把使用者原始自然語言轉成任意網站操作指令，而應收斂為有限、可審計、可測試的 action，例如「查訂單」「查庫存」「下載報表」等。

第一版建議優先只開放 read-only 查詢，不先開放寫入、送單、審批或刪除等高風險操作。

## Skyvern 在架構中的角色

Skyvern 的核心概念包含 Tasks、Credentials、Browser Sessions、Artifacts、Runs 與 Workflows，這些都對應到內部自動化引擎會需要的管理能力。

官方文件顯示 Skyvern 可透過 self-host、REST API、Python SDK 與 TypeScript SDK 整合，並支援指定 self-hosted base URL，因此很適合作為內網服務被其他後端系統呼叫。

Skyvern 也支援 login、stored credentials、2FA/TOTP、persistent browser sessions 與多步驟 task 執行，足以覆蓋常見 ERP 查詢自動化情境。

## 建議的系統分層

| 分層 | 主要責任 |
|---|---|
| SaaS 前台 | 使用者登入、租戶隔離、自然語言輸入、查詢表單、結果展示 |
| API / BFF | 驗證、權限檢查、prompt 收斂、action mapping、建立 task、讀取結果 |
| Queue / Worker | 非同步執行、重試、超時控制、任務編排 |
| Skyvern | 登入 ERP、操作頁面、擷取資料、下載報表、維持 browser session |
| ERP Web + MySQL | 業務邏輯、原生權限、交易資料、報表資料、選單可見性 |
| 控制資料庫 | 綁定資料、任務狀態、審計、結果索引、session cache |

上表中的 Skyvern 層不承擔產品前台責任；其定位是被動接受內部服務指派的 automation job。

## 建議操作流程

### 使用者查詢流程

1. 使用者登入自家 SaaS。
2. 使用者輸入自然語言查詢，例如「查 6 月未結帳訂單」。
3. API/BFF 驗證 SaaS 使用者身份與租戶關係。
4. API/BFF 依據白名單 action 將自然語言收斂成受控查詢指令。
5. 系統查找該使用者對應的 ERP account binding 與 Skyvern credential reference。
6. Worker 建立或重用該使用者專屬的 `browser_session_id`。
7. Skyvern 以該使用者 ERP 身份登入，進入其實際可見的 ERP 畫面範圍。
8. Skyvern 執行查詢流程，擷取結果並回傳結構化資料或下載檔案索引。
9. 結果存入控制資料庫，前台再以輪詢或 WebSocket 顯示進度與結果。

### Session 操作原則

Skyvern 支援建立 browser session，並在同一 session 中延續登入狀態、cookies 與頁面上下文，因此同一位使用者的後續查詢可優先嘗試重用 session，以降低重複登入成本與失敗率。

但 session 必須明確綁定 `tenant_id`、`user_id`、`erp_account_id` 與 `browser_session_id`，避免 A 使用者的登入狀態被 B 使用者誤用。

## 控制資料庫策略

### 為什麼仍需要一個控制資料庫

即使 ERP 已有完整 MySQL，整合層仍需要一個自家控制資料庫，因為 ERP 不會替 Skyvern 管理 SaaS 租戶、跨系統帳號綁定、任務狀態、執行紀錄、artifact 索引與審計資料。

此資料庫只需管理「Skyvern 部分」與「SaaS 對 ERP 的映射關係」，不需複製 ERP 全部業務表。

### MongoDB 是否可用

若控制資料庫只負責 Skyvern 這側的任務文件、執行日誌、JSON 擷取結果、artifact 索引與 session cache，MongoDB 是可行選項，因為這類資料結構常偏文件型、欄位彈性高，且結果格式可能經常變化。

若控制資料庫還要承擔大量複雜關聯、跨表報表、嚴格一致性的核心交易型資料，PostgreSQL 通常更自然；但本案已明確將 ERP 業務資料保留在既有 MySQL，因此控制資料庫切到 MongoDB 的風險與複雜度相對降低。

### 建議保存在控制資料庫的資料

- `users`：SaaS 使用者基本識別資料。
- `erp_account_bindings`：SaaS user 與 ERP account 的 1:1 綁定。
- `skyvern_credentials`：Skyvern credential id 或 vault reference。
- `browser_sessions`：每位使用者目前與最近的 session 狀態。
- `automation_tasks`：任務類型、狀態、耗時、錯誤原因、重試次數。
- `task_results`：結構化查詢結果、JSON payload、提取摘要。
- `artifacts_index`：截圖、下載檔、報表、頁面產物位置。
- `audit_logs`：誰發起了什麼查詢、何時執行、用了哪個 ERP 身份、結果是否成功。

## 安全與權限原則

### 憑證管理

ERP 帳密、TOTP secret、cookie 或其他敏感資料不應存放在前端。Skyvern 文件顯示其登入流程與 credential 管理可搭配密碼憑證與其他秘密資料來源，因此較合理的做法是由後端或 vault 管理，再在執行時注入。

### 以使用者本人身份執行

本案的安全基礎是「每位使用者有唯一 ERP 帳號」。只要 Skyvern 始終以該使用者自己的 ERP 身份登入並操作，ERP 原生的功能可見性與資料範圍就能成為第一層權限邊界。

### 不使用共用高權限帳號

不建議使用單一管理員或共用 ERP 帳號服務所有客戶，否則 Skyvern 的可見範圍會以該高權限帳號為準，等於把 ERP 原本的權限隔離破壞掉。

### 審計與可追蹤性

每個 task 應至少記錄發起 SaaS user、tenant、ERP account、browser session、action type、prompt 原文、結構化 action、結果狀態與 artifacts 位置，方便除錯、稽核與責任追蹤。

## AGPL-3.0 授權注意事項

Skyvern 開源核心採 AGPL-3.0 授權；GNU AGPL 對「透過網路提供互動服務」有特別要求，若修改後的程式透過網路給使用者互動，通常需要向這些使用者提供對應原始碼的取得方式。

因此，本案較穩妥的做法是：不要把 Skyvern UI 直接作為對外 SaaS 平台，而是把 Skyvern 放在內部 automation layer，由自家前台與 API 隔離對外。

## 第一版 MVP 建議範圍

第一版產品建議聚焦在少數高價值、低風險、只讀查詢場景，以縮小 prompt 變異與操作風險。

建議優先開放：

- 查訂單列表與狀態。
- 查庫存與商品可用量。
- 查未結帳或逾期資料。
- 下載既有報表。
- 回傳表格式 JSON 或 CSV 索引。

暫緩項目：

- 建立或修改交易資料。
- 送審、審批、核銷、刪除等不可逆操作。
- 讓使用者直接輸入任意網站操作指令。

## 對後續 agent / 設計人員的提示

### 給工程 agent

- 把 Skyvern 視為內部 worker service，不是前台產品。
- 先設計 action whitelist 與 output schema，再做 prompt 細節。
- 所有 task 都必須帶上 user / tenant / erp account / session 綁定資訊。
- 優先做 read-only flow 與錯誤復原。
- 控制資料庫只存整合層資料，不重建 ERP schema。

### 給產品 / UX 設計人員

- 使用者感知到的是「自然語言查 ERP」，不是「使用一個 browser automation 工具」。
- 前台應強調結果可信度、查詢進度、可下載產物、權限可見範圍與錯誤提示。
- 介面上不建議暴露過多 agent 自由度，應使用受控查詢入口、模板化查詢與明確的結果格式。
- 對等待時間要有 progress UI，因為 browser automation 通常比直接 SQL/API 查詢慢。

## 後續可直接展開的實作項目

1. 定義 action whitelist，例如 `query_orders`、`query_inventory`、`download_report`。
2. 定義每個 action 的輸入 schema、結果 schema 與錯誤碼。
3. 設計控制資料庫 collections / tables。
4. 建立 ERP account binding 與 credential mapping 流程。
5. 建立 browser session lifecycle 管理機制。
6. 實作任務狀態機：queued、running、succeeded、failed、expired。
7. 加入 audit log 與 artifact 索引。
8. 先從單一 ERP 查詢頁面的穩定流程開始驗證，再逐步擴充能力。

## 最終結論

本案目前最合理的方案是：外部客戶登入自家 SaaS，後端透過 Skyvern 的 REST API 或 SDK，以每位使用者自己的 ERP 身份進入既有 Web ERP，執行受控的查詢型自動化流程；ERP 的 MySQL 保留為業務主資料來源，而 Skyvern 只管理自動化整合層的 metadata、session、任務結果與審計資訊。

在此前提下，控制資料庫改用 MongoDB 是可行的，前提是它只負責 Skyvern 這一側的文件型資料與整合 metadata，而不承擔 ERP 核心交易資料的一致性責任。
