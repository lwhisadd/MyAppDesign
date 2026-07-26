# Windows 桌面版 Codex：`mattpocock/skills` 專案級安裝與安全調整執行書

> 文件用途：將本文件放在要使用 Skills 的專案根目錄，交由 Windows 桌面版 Codex 讀取並依序執行。
>
> 審核日期：2026-07-25（Asia/Taipei）  
> 上游專案：<https://github.com/mattpocock/skills>  
> 審核基準提交：`ed37663cc5fbef691ddfecd080dff42f7e7e350d`  
> 安裝器專案：<https://github.com/vercel-labs/skills>  
> 審核時安裝器版本：`skills 1.5.20`；其 `package.json` 要求 Node.js `>=22.20.0`  
> 適用範圍：Windows 桌面版 Codex／目前開啟的單一 Git 專案  
> 安裝範圍：只允許專案級 `.agents/skills/`，禁止全域 Skills 安裝

---

## 一、交給 Codex 的任務

請完成以下工作：

1. 檢查目前專案、Git、Node.js、npm 與 `npx` 環境。
2. 從 `mattpocock/skills` 安裝本文件指定的 Skills 到目前專案的 `.agents/skills/`。
3. 驗證每個 Skill 的 `SKILL.md`、`agents/openai.yaml` 與專案根目錄的 `skills-lock.json`。
4. 套用本文件列出的「安裝後本機調整」，避免自動提交、未經核准改動 Issue Tracker、錯誤使用背景代理，以及更新時覆寫安全規則。
5. 將長期專案規則合併到根目錄 `AGENTS.md`，不得破壞原有內容。
6. 建立 `docs/agents/mattpocock-skills-local-adjustments.md`，記錄實際安裝版本、調整項目及日後更新程序。
7. 嘗試在 Windows 桌面版 Codex 中載入並執行 `setup-matt-pocock-skills`；若目前工作階段無法重新索引新安裝的 Skills，必須明確回報需要開啟新工作階段，不得假稱已完成 setup。
8. 最後提供可稽核的完成報告，不得只說「已完成」。

本文件已授權的寫入範圍只有：

- `.agents/skills/`
- `skills-lock.json`
- 根目錄 `AGENTS.md` 內本文件指定的標記區塊
- `docs/agents/mattpocock-skills-local-adjustments.md`
- `setup-matt-pocock-skills` 經使用者逐題確認後所核准的專案內文件

除此之外的檔案、Git 狀態或外部系統變更，都需要另外取得明確核准。

---

## 二、最高優先操作規則

執行本文件時，以下規則高於所安裝 Skill 內任何相反指示：

1. **所有對使用者顯示的訊息、問題、摘要、報告與新建文件，一律使用繁體中文。**
2. **不要猜測使用者的決策。** 可由環境查證的事實先自行查證；確實需要使用者決定時，一次只問一題，並同時給出建議答案與簡短理由。
3. 本次只處理目前開啟的專案。不得使用 `-g`、`--global`，不得寫入使用者層級的 Skills 目錄，也不得修改全域 Codex、Git、npm 或 PowerShell 設定。
4. 不需要安裝 `@openai/codex` CLI。Windows 桌面版 Codex 已是執行環境；本流程只需要 Git、Node.js、npm 與 `npx` 來安裝 Skills。
5. 不得自動執行 `git commit`、`git push`、`git merge`、`git rebase`、建立 PR、切換或建立分支、加標籤，除非使用者在看過本次變更與驗證結果後，明確要求該項操作。
6. 不得未經核准建立、修改、指派、留言、關閉或標記 GitHub／GitLab／其他 Issue Tracker 項目。
7. 不得執行破壞性清理，例如 `git clean`、`git reset --hard`、遞迴刪除既有目錄，或覆寫無關的未提交變更。
8. 保留既有 `AGENTS.md`、`CLAUDE.md`、`CONTEXT.md`、ADR、`docs/agents/` 與 `plan/` 結構。相同用途的資料夾不得重複建立。
9. 若專案已存在 `plan/`、`plan/troubleshooting/`、`plan/break_plan/` 等規劃目錄，後續規格與計畫應沿用既有慣例；不得自行改成另一套重複結構。
10. 不得承諾稍後或背景完成。只有目前環境確實支援子代理，且使用者已核准時，才能啟動子代理；否則改以目前工作階段同步完成。
11. 任一命令失敗時，停止該階段，回報原始命令、退出狀態、關鍵錯誤與已完成項目。不得為了繞過錯誤而改做全域安裝。
12. 所有修改必須具備可重複執行性：再次執行時更新既有標記區塊，不得重複附加相同規則。

---

## 三、人類使用方式

1. 將本文件放入目標專案根目錄，檔名可維持：

   ```text
   codex_windows_mattpocock_skills_install_zh-TW.md
   ```

2. 使用 Windows 桌面版 Codex 開啟該專案。
3. 對 Codex 輸入：

   ```text
   請完整讀取 codex_windows_mattpocock_skills_install_zh-TW.md，依文件順序完成安裝、驗證、安裝後調整與紀錄。只可修改文件明確授權的範圍。所有訊息使用繁體中文；需要我決定時一次只問一題。
   ```

4. 建議維持 Codex 的工作區寫入與核准機制，不要為了本次安裝切換成無限制的 Full Access。

---

# Codex 執行程序

## 階段 0：確認專案範圍與建立非破壞性備份

### 0.1 確認目前資料夾是正確的 Git 專案

在整合式 PowerShell 終端執行：

```powershell
git rev-parse --show-toplevel
git status --short
git remote -v
```

處理規則：

- 將 `git rev-parse --show-toplevel` 的結果視為唯一專案根目錄，後續先切換到該目錄。
- 若不是 Git repository，只問一題：
  - 「目前資料夾不是 Git repository。是否要在此初始化 Git？建議：否，先確認是否開啟了正確專案。」
- 若工作樹已有未提交變更，不得還原或覆蓋；先列出與本次授權路徑重疊的檔案。
- 若已存在 `.agents/skills/` 或 `skills-lock.json`，視為更新／補強情境，不得直接當成全新安裝。

### 0.2 檢查必要工具

```powershell
git --version
node --version
npm --version
npx --version
```

Node.js 版本檢查：

```powershell
$nodeVersion = [version]((node --version).Trim().TrimStart('v'))
$minimumNodeVersion = [version]'22.20.0'
if ($nodeVersion -lt $minimumNodeVersion) {
    throw "目前 Node.js 為 $nodeVersion；skills 1.5.20 要求 Node.js >= $minimumNodeVersion。"
}
```

處理規則：

- 缺少 Git、Node.js、npm 或 `npx` 時，不得自行安裝或修改 PATH。
- 一次只問一題是否允許安裝／升級缺少的工具，並說明建議版本。
- 不得把安裝 Codex CLI 列為桌面版的必要條件。

### 0.3 盤點本次可能碰觸的既有內容

依序讀取或列出：

```text
AGENTS.md
CLAUDE.md
CONTEXT.md
CONTEXT-MAP.md
docs/agents/
docs/adr/
plan/
.agents/skills/
skills-lock.json
```

先摘要：

- 哪些檔案已存在。
- 哪些檔案有未提交變更。
- 是否同時存在 `AGENTS.md` 與 `CLAUDE.md`。
- 是否已有 Matt Pocock Skills 或同名本機調整。

### 0.4 備份既有相關檔案到 Windows 暫存目錄

此備份不放入 repository：

```powershell
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupRoot = Join-Path $env:TEMP "mattpocock-skills-backup-$stamp"
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null

$backupItems = @(
    '.agents\skills',
    'skills-lock.json',
    'AGENTS.md',
    'CLAUDE.md',
    'docs\agents'
)

foreach ($item in $backupItems) {
    if (Test-Path $item) {
        $destination = Join-Path $backupRoot $item
        $destinationParent = Split-Path $destination -Parent
        New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
        Copy-Item $item -Destination $destination -Recurse -Force
    }
}

Write-Output "備份位置：$backupRoot"
```

完成報告需列出實際備份路徑。不得把備份中的敏感資料貼入對話。

---

## 階段 1：先列出上游可用 Skills，不直接安裝

執行：

```powershell
npm view skills version
npx --yes skills@latest add mattpocock/skills --list
```

將命令輸出與下列預定清單比對：

```text
setup-matt-pocock-skills
grill-with-docs
grilling
domain-modeling
to-spec
to-tickets
implement
tdd
diagnosing-bugs
code-review
codebase-design
improve-codebase-architecture
wayfinder
research
prototype
```

規則：

- 必須使用上游實際列出的名稱，不得猜測或自動更名。
- 若任何預定 Skill 已不存在、改名或移入 deprecated／in-progress，停止安裝並一次只問一題是否採用上游替代項目。
- 不安裝 `skills/in-progress/`、`skills/personal/`、`skills/deprecated/` 下的內容。
- 本次不自動加裝 `triage`、`ask-matt`、`handoff` 或 `resolving-merge-conflicts`；它們不屬於本次已核准的核心清單。

---

## 階段 2：安裝到目前專案的 `.agents/skills/`

確認目前位置是 repository root，執行下列 PowerShell 命令：

```powershell
npx --yes skills@latest add mattpocock/skills `
  -a codex `
  --copy `
  -y `
  --skill setup-matt-pocock-skills `
  --skill grill-with-docs `
  --skill grilling `
  --skill domain-modeling `
  --skill to-spec `
  --skill to-tickets `
  --skill implement `
  --skill tdd `
  --skill diagnosing-bugs `
  --skill code-review `
  --skill codebase-design `
  --skill improve-codebase-architecture `
  --skill wayfinder `
  --skill research `
  --skill prototype
```

安裝約束：

- `-a codex`：目標代理為 Codex。
- `--copy`：Windows 使用實體複本，避免 symlink 權限與開發人員模式差異。
- 不得加入 `-g` 或 `--global`。
- 預期專案路徑為 `.agents/skills/<skill-name>/`。
- 預期產生或更新根目錄 `skills-lock.json`。
- 安裝過程需要連線 npm 與 GitHub；除此之外不得擴大網路存取範圍。

若命令想安裝到其他代理或全域路徑，立即取消並回報，不得接受預設值。

---

## 階段 3：驗證安裝結果

### 3.1 由安裝器列出 Codex Skills

```powershell
npx --yes skills@latest list -a codex
```

### 3.2 檢查必要檔案

```powershell
$requiredSkills = @(
    'setup-matt-pocock-skills',
    'grill-with-docs',
    'grilling',
    'domain-modeling',
    'to-spec',
    'to-tickets',
    'implement',
    'tdd',
    'diagnosing-bugs',
    'code-review',
    'codebase-design',
    'improve-codebase-architecture',
    'wayfinder',
    'research',
    'prototype'
)

$missing = @()
foreach ($name in $requiredSkills) {
    $skillFile = Join-Path ".agents\skills\$name" 'SKILL.md'
    $openAiMetadata = Join-Path ".agents\skills\$name" 'agents\openai.yaml'

    if (-not (Test-Path $skillFile)) {
        $missing += $skillFile
    }
    if (-not (Test-Path $openAiMetadata)) {
        $missing += $openAiMetadata
    }
}

if (-not (Test-Path 'skills-lock.json')) {
    $missing += 'skills-lock.json'
}

if ($missing.Count -gt 0) {
    Write-Error ("缺少必要檔案：`n" + ($missing -join "`n"))
} else {
    Write-Output '所有必要 Skill、Codex 中繼資料與 skills-lock.json 均存在。'
}
```

### 3.3 檢查 Skill 內容與 Codex 呼叫政策

逐一確認：

- `SKILL.md` 的 YAML frontmatter 至少有 `name` 與 `description`。
- `agents/openai.yaml` 可被讀取。
- 下列使用者主動呼叫型 Skills 應保留 `policy.allow_implicit_invocation: false`：
  - `setup-matt-pocock-skills`
  - `grill-with-docs`
  - `to-spec`
  - `to-tickets`
  - `implement`
  - `improve-codebase-architecture`
  - `wayfinder`
- 不得把所有 Skills 一律改為自動呼叫，也不得任意刪除上游 `agents/openai.yaml`。

### 3.4 記錄實際來源資訊

讀取 `skills-lock.json`，記錄：

- 每個 Skill 的來源。
- `ref`（若有）。
- `skillPath`。
- `computedHash`。

審核基準提交 `ed37663...` 只代表本文件撰寫時檢查的版本。實際安裝若來自較新的上游版本，以 `skills-lock.json` 與安裝輸出為準；不得把審核基準誤寫成實際安裝提交。

---

## 階段 4：套用安裝後本機調整

### 4.1 共通修改原則

1. 修改前先讀完整檔案，不得只依本文件中的舊行號或舊字串盲目取代。
2. 若上游內容已變更，先判斷語意是否仍有相同風險，再做最小修改。
3. 每個本機覆寫區塊使用下列標記，重跑時更新原區塊：

   ```markdown
   <!-- project-local-policy:start -->
   ...
   <!-- project-local-policy:end -->
   ```

4. 不得改動 Skill 的 `name`、資料夾名稱或 `agents/openai.yaml` 呼叫政策，除非本文件明確要求。
5. 保留上游 MIT License 的著作權與授權資訊。
6. 修改完成後，用 `git diff -- .agents/skills` 顯示差異並檢查是否只有預期調整。

### 4.2 調整 `implement`：移除自動提交

目標檔案：

```text
.agents/skills/implement/SKILL.md
```

上游審核版本最後要求：

```text
Commit your work to the current branch.
```

將此要求替換成下列本機政策；若上游文字已變更，依相同語意調整，不得同時保留無條件自動提交要求：

```markdown
<!-- project-local-policy:start -->
## 專案本機覆寫：版本控制核准

完成實作與 code review 後，先向使用者顯示：

1. 實際變更檔案與變更摘要。
2. 執行過的驗證命令及結果。
3. 尚未處理的風險、失敗或未執行項目。

除非使用者在看過上述結果後，明確要求該項操作，否則不得 commit、push、merge、rebase、建立或更新 PR、建立標籤或改動遠端狀態。
<!-- project-local-policy:end -->
```

### 4.3 調整 `to-spec`：發布前必須核准完整草稿

目標檔案：

```text
.agents/skills/to-spec/SKILL.md
```

在「發布到 Issue Tracker」之前加入並落實：

```markdown
<!-- project-local-policy:start -->
## 專案本機覆寫：規格發布核准

先產生並完整顯示規格草稿、測試 seam、目標 Issue Tracker、預計建立或修改的項目，以及預計套用的標籤。等待使用者明確核准後，才可發布或修改 Issue Tracker。

使用者只核准草稿內容，不等於核准外部發布；發布核准必須明確涵蓋目標 repository、Issue 動作與標籤。未取得核准時，只回傳草稿，不得建立 Issue、留言或套用標籤。
<!-- project-local-policy:end -->
```

並把原流程中「直接 publish」的文字改成「取得明確核准後 publish」。

### 4.4 調整 `to-tickets`：核准範圍必須包含外部副作用

目標檔案：

```text
.agents/skills/to-tickets/SKILL.md
```

保留上游既有的顆粒度與 blocking edges 確認流程，再加入：

```markdown
<!-- project-local-policy:start -->
## 專案本機覆寫：Ticket 發布核准

發布前的預覽必須列出：Ticket 數量、標題、父子關係、blocking edges、目標 tracker、預計標籤，以及將建立或修改的外部項目。只有使用者明確核准這一批預覽後，才可發布。

核准只涵蓋預覽中列出的精確動作。若數量、依賴、標籤或目標 repository 改變，必須重新取得核准。不得修改或關閉來源／父 Issue，除非使用者另行明確要求。
<!-- project-local-policy:end -->
```

### 4.5 調整 `setup-matt-pocock-skills`：Codex 專案優先使用 `AGENTS.md`

目標檔案：

```text
.agents/skills/setup-matt-pocock-skills/SKILL.md
```

將檔案選擇規則調整為：

```markdown
<!-- project-local-policy:start -->
## 專案本機覆寫：Codex 指示檔選擇

本專案以 Codex 為主要執行環境：

1. 若根目錄已有 `AGENTS.md`，更新其中既有的 `## Agent skills` 或本專案標記區塊，不得改寫其他段落。
2. 若同時存在 `AGENTS.md` 與 `CLAUDE.md`，本次 Codex 專案固定更新 `AGENTS.md`，不得改寫 `CLAUDE.md`。
3. 若只有 `CLAUDE.md`，一次只問一題是否建立 Codex 專用 `AGENTS.md`；建議答案為「是」。
4. 若兩者都不存在，因本次目標明確為 Codex，可建議建立 `AGENTS.md`，但仍須先顯示草稿。
5. 不得建立重複的 Agent skills 區塊，也不得把既有 `plan/` 規劃文件搬到新目錄。
<!-- project-local-policy:end -->
```

原本「同時存在時直接優先選 `CLAUDE.md`」的規則不得繼續生效。

### 4.6 調整 `wayfinder`：Issue、分支及背景研究全部加上核准閘門

目標檔案：

```text
.agents/skills/wayfinder/SKILL.md
```

加入：

```markdown
<!-- project-local-policy:start -->
## 專案本機覆寫：外部狀態與 Git 核准閘門

Wayfinder 的規劃內容可以先在對話中產生，但下列動作均屬外部副作用：建立或修改 Map／Issue、建立子 Issue、設定 blocking、指派、加標籤、留言、關閉 Issue、建立或切換分支、commit、push，以及啟動會寫入 repository 或 tracker 的背景代理。

在第一個外部副作用前，必須完整預覽這一批動作、目標 repository、項目數量、名稱、關係及分支名稱，並等待使用者明確核准。核准只適用於預覽中的精確批次；範圍改變時必須重新核准。

未取得核准時，只能輸出本機草稿或對話內草稿，不得改動 Git、Issue Tracker 或遠端狀態。不得把「使用者要求規劃」解讀成已核准建立 Issue 或分支。
<!-- project-local-policy:end -->
```

### 4.7 調整 `research`：背景代理不可用時同步執行

目標檔案：

```text
.agents/skills/research/SKILL.md
```

加入：

```markdown
<!-- project-local-policy:start -->
## 專案本機覆寫：執行模式與寫檔核准

只有目前 Codex 環境確實提供背景／子代理，且使用者已核准該執行方式時，才可使用背景代理。否則必須在目前工作階段同步完成研究，不得承諾稍後交付。

研究仍以第一方文件、原始碼、規格及官方 API 為主。若使用者已明確要求產生 Markdown 檔，可寫入其指定位置；若沒有指定寫入位置，先提出建議路徑並取得核准，不得自行在 repository 建立新資料夾。
<!-- project-local-policy:end -->
```

### 4.8 調整 `code-review`：沒有平行子代理時使用循序雙軸審查

目標檔案：

```text
.agents/skills/code-review/SKILL.md
```

加入：

```markdown
<!-- project-local-policy:start -->
## 專案本機覆寫：子代理降級方案與唯讀限制

若目前環境沒有可用的平行子代理，依序執行 Standards 軸與 Spec 軸審查，兩份結果仍須保持分離，不得彼此抵銷或重新排序成單一結論。

Code review 預設為唯讀工作。除非使用者另行明確要求修正，否則不得修改程式碼、規格、Issue、Git 狀態或遠端內容。
<!-- project-local-policy:end -->
```

### 4.9 調整 `improve-codebase-architecture`：報告預設離線、自包含

目標檔案：

```text
.agents/skills/improve-codebase-architecture/SKILL.md
```

加入：

```markdown
<!-- project-local-policy:start -->
## 專案本機覆寫：離線報告與網路資源

架構報告預設必須是可離線開啟的單一 HTML：CSS、圖示與必要 SVG 直接內嵌。未取得使用者明確核准前，不得載入 Tailwind、Mermaid 或其他遠端 CDN 資源。

若目前環境無法啟動 Explore／設計子代理，改由目前工作階段循序完成並清楚標示限制。若無法自動開啟瀏覽器，回報報告的 Windows 絕對路徑，不得因此宣稱產生失敗。
<!-- project-local-policy:end -->
```

### 4.10 其他已安裝 Skills

下列 Skills 不需要改寫核心內容，但仍受 `AGENTS.md` 共通規則約束：

- `grill-with-docs`
- `grilling`
- `domain-modeling`
- `tdd`
- `diagnosing-bugs`
- `codebase-design`
- `prototype`

確認事項：

- `grilling` 必須一次只問一題，並對每題提供建議答案。
- `domain-modeling` 只有在術語已由使用者確認後才更新 `CONTEXT.md`；`CONTEXT.md` 只作為領域詞彙表。
- `diagnosing-bugs` 在提出根因前，必須先建立能針對精確症狀失敗的重現／回饋命令。
- `prototype` 產物預設為可拋棄，不得未經要求混入正式程式碼。

---

## 階段 5：合併專案級 `AGENTS.md` 規則

### 5.1 檔案選擇

- 若根目錄已有 `AGENTS.md`：保留所有既有內容，只新增或更新下列標記區塊。
- 若同時存在 `AGENTS.md` 與 `CLAUDE.md`：本次只修改 `AGENTS.md`；不得同步改寫 `CLAUDE.md`。
- 若只有 `CLAUDE.md`：一次只問一題是否建立 `AGENTS.md`，建議答案為「是，Codex 專案規則應放在 `AGENTS.md`」。
- 若兩者都不存在：建立 `AGENTS.md` 前先顯示完整草稿；本文件已明確指定 Codex，因此建議建立。

### 5.2 要合併的標記區塊

```markdown
<!-- mattpocock-skills:local-policy:start -->
## Matt Pocock Skills 專案操作規則

- 所有對使用者顯示的訊息、問題、摘要與新建文件一律使用繁體中文。
- 可由檔案、Git、工具或官方文件查證的事實先自行查證，不要拿事實問題詢問使用者。
- 確實需要使用者決定時，一次只問一題；每題同時給出建議答案與簡短理由。不得把未回答視為同意。
- Skills 僅安裝於本專案 `.agents/skills/`；不得修改全域 Skills、全域 Codex 設定、全域 Git／npm 設定。
- 保留既有 `plan/`、`docs/`、`CONTEXT.md` 與 ADR 慣例，不得建立相同用途的重複資料夾。
- 開始實作前，讀取相關 `CONTEXT.md`、ADR、規格、Ticket 與專案規範；若內容矛盾，先指出矛盾並詢問一題。
- 未經使用者明確要求，不得 commit、push、merge、rebase、建立 PR、建立／切換分支或修改遠端狀態。
- 建立、修改、指派、標記、留言或關閉 Issue 前，先預覽精確變更並取得核准；規劃要求不等於核准外部寫入。
- `implement` 完成後先回報變更、驗證命令與結果、未解風險，不得自行提交。
- `to-spec` 與 `to-tickets` 必須先顯示完整草稿與外部發布計畫，取得明確核准後才可發布。
- `wayfinder` 的 Issue、blocking、指派、關閉、分支與背景研究均需逐批核准。
- 若背景或平行子代理不可用，改在目前工作階段同步或循序完成；不得承諾稍後交付。
- Bug 修正前先建立可針對精確症狀變紅的重現命令；沒有證據前不得猜測根因。
- 任務交接必須列出精確驗證命令、實際結果、未執行項目與風險；不得只說「已完成」。
- 更新第三方 Skills 前先備份並審查差異；更新後重新套用及驗證 `docs/agents/mattpocock-skills-local-adjustments.md` 中的本機安全調整。
<!-- mattpocock-skills:local-policy:end -->
```

合併後檢查：

- 標記區塊只出現一次。
- 沒有刪除或改寫使用者原有規則。
- 若原規則與本區塊衝突，列出衝突並一次只問一題，不得自行選邊。

---

## 階段 6：建立本機調整紀錄

建立或更新：

```text
docs/agents/mattpocock-skills-local-adjustments.md
```

至少包含下列內容：

```markdown
# Matt Pocock Skills 本機調整紀錄

## 安裝資訊

- 安裝日期：<實際日期與時區>
- 安裝器版本：<npm view skills version 的結果>
- 上游來源：https://github.com/mattpocock/skills
- 本文件審核基準：ed37663cc5fbef691ddfecd080dff42f7e7e350d
- 實際來源／ref／hash：<依 skills-lock.json 填寫，不得猜測>
- 安裝範圍：專案級 `.agents/skills/`
- 安裝模式：Copy
- 目標代理：Codex

## 已安裝 Skills

<逐項列出 15 個 Skills>

## 本機調整

| Skill／檔案 | 本機調整目的 | 驗證方式 |
|---|---|---|
| implement | 禁止未核准 commit／push／PR | 檢查 SKILL.md 的版本控制核准區塊 |
| to-spec | 規格發布前顯示完整草稿並取得核准 | 檢查發布核准區塊 |
| to-tickets | Ticket 與標籤發布逐批核准 | 檢查 Ticket 發布核准區塊 |
| setup-matt-pocock-skills | Codex 優先 AGENTS.md，避免默認 CLAUDE.md | 檢查檔案選擇區塊 |
| wayfinder | Issue、分支與背景作業核准閘門 | 檢查外部狀態區塊 |
| research | 無背景代理時同步執行；寫檔路徑核准 | 檢查執行模式區塊 |
| code-review | 無子代理時循序雙軸；預設唯讀 | 檢查降級方案區塊 |
| improve-codebase-architecture | 預設離線、自包含 HTML | 檢查離線報告區塊 |
| AGENTS.md | 專案共通安全與溝通規則 | 確認標記區塊只出現一次 |

## 更新警告

`npx skills update -p` 會重新取得上游內容，本機修改可能被覆寫。每次更新都必須依本文件的更新程序備份、檢查差異、重新套用調整並驗證。

## 回復原則

- 不使用 `git reset --hard` 或 `git clean`。
- 優先使用本次執行前的 Windows 暫存備份與 `git diff` 精準回復。
- 刪除或還原檔案前，先列出精確目標並取得使用者核准。
```

若 `docs/agents/` 已有同用途文件，更新既有文件，不得建立第二份重複紀錄。

---

## 階段 7：執行專案 setup

### 7.1 先確認 Windows 桌面版 Codex 已重新索引 Skills

- 在桌面應用程式的 Skills 側邊欄確認 `setup-matt-pocock-skills` 可見。
- 若目前工作階段可直接載入新 Skill，執行它。
- 若不可見，先完成所有檔案驗證，然後明確回報需要在相同專案開啟新工作階段或重新啟動桌面應用程式。
- 不得把 CLI／IDE 的 `/skills` 或 `$skill-name` 語法當成桌面版唯一操作方法。

### 7.2 setup 的執行約束

執行 `setup-matt-pocock-skills` 時：

1. 先讀取 Git remote、`AGENTS.md`、`CLAUDE.md`、`CONTEXT.md`、`CONTEXT-MAP.md`、`docs/adr/`、`docs/agents/`、`.scratch/` 與 monorepo 訊號。
2. 先顯示目前狀態與建議，不得直接寫檔。
3. Issue Tracker 屬於使用者決策：根據 remote 提出建議後，一次只問一題。
4. 未安裝 `triage` 時，不建立 triage labels 文件；`to-spec`／`to-tickets` 也不得自行套用不存在或未核准的標籤。
5. 一般單一 repository 可建議 single-context；只有實際存在 monorepo 訊號時才提出 multi-context。
6. 使用 `AGENTS.md` 作為 Codex 規則來源；不得因上游預設而自動改寫 `CLAUDE.md`。
7. 沿用既有 `plan/` 與相關子目錄。
8. 寫入前完整顯示：
   - `AGENTS.md` 要更新的區塊。
   - `docs/agents/issue-tracker.md` 草稿。
   - `docs/agents/domain.md` 草稿。
   - 其他預計建立或修改的檔案。
9. 每次只詢問一個決策；使用者核准草稿後才寫入。

若需要在新工作階段繼續，提供下列提示詞：

```text
請在目前專案載入 setup-matt-pocock-skills。先讀取 AGENTS.md 與 docs/agents/mattpocock-skills-local-adjustments.md，依其中安全規則執行。先檢查專案並顯示建議；需要我決定時一次只問一題。未經我核准，不得修改 Issue Tracker、Git 狀態或遠端內容。
```

---

## 階段 8：完整驗證

### 8.1 檔案與調整驗證

確認：

- 15 個必要 Skill 均存在。
- 每個 Skill 均有 `SKILL.md` 與 `agents/openai.yaml`。
- `skills-lock.json` 存在且可解析。
- `AGENTS.md` 本機規則標記只出現一次。
- 8 個高風險 Skill 的本機覆寫標記均存在且只出現一次：
  - `implement`
  - `to-spec`
  - `to-tickets`
  - `setup-matt-pocock-skills`
  - `wayfinder`
  - `research`
  - `code-review`
  - `improve-codebase-architecture`
- `docs/agents/mattpocock-skills-local-adjustments.md` 已記錄實際來源資訊。

可使用：

```powershell
git diff -- AGENTS.md skills-lock.json .agents/skills docs/agents/mattpocock-skills-local-adjustments.md

git status --short
```

### 8.2 安全驗證

搜尋下列風險：

```powershell
Get-ChildItem '.agents\skills' -Recurse -File | `
  Select-String -Pattern 'Commit your work|git push|create.*PR|background agent|Tailwind via CDN|Mermaid via CDN'
```

對搜尋結果逐一判斷：

- 不是只看關鍵字是否存在，而是確認本機覆寫是否明確限制其執行條件。
- `implement` 不得仍存在無條件「完成即 commit」的有效指示。
- `wayfinder` 不得仍允許未核准外部寫入。
- `research` 不得在環境不支援時承諾背景完成。
- 架構報告不得預設依賴遠端 CDN。

### 8.3 不得執行的驗證方式

- 不得為了測試而建立真實 Issue、PR、分支或 commit。
- 不得向遠端 repository 推送測試內容。
- 不得修改使用者全域 Skills 或 Codex 設定。
- 不得使用破壞性命令把工作樹恢復成乾淨狀態。

---

## 階段 9：完成報告格式

最終必須以繁體中文提供下列報告：

```markdown
# Matt Pocock Skills 安裝完成報告

## 執行範圍
- Repository root：
- Git remote：
- 安裝範圍：專案級／全域未修改
- 備份位置：

## 環境
- Git：
- Node.js：
- npm：
- npx：
- skills 安裝器版本：

## 安裝結果
- 已安裝 Skills：
- 安裝路徑：
- skills-lock.json：存在／不存在
- Codex Skills 側邊欄：已辨識／需重啟或新工作階段

## 安裝後調整
- implement：
- to-spec：
- to-tickets：
- setup-matt-pocock-skills：
- wayfinder：
- research：
- code-review：
- improve-codebase-architecture：
- AGENTS.md：
- 本機調整紀錄：

## 驗證證據
- 執行命令：
- 命令結果：
- git diff 摘要：
- git status 摘要：

## Setup 狀態
- 已完成／等待新工作階段
- 已確認的 Issue Tracker：
- 已確認的 Domain docs 佈局：
- 實際建立或修改的 setup 文件：

## 未執行項目與風險
- 未執行：
- 原因：
- 下一個必要動作：

## 外部狀態聲明
- 未 commit
- 未 push
- 未建立或修改 PR
- 未建立、修改、指派、標記、留言或關閉 Issue
- 未修改全域 Skills 或全域 Codex 設定
```

若任一聲明不成立，必須如實列出實際動作、核准依據與目標，不得保留錯誤的「未執行」文字。

---

# 日後更新程序

## 原則

專案級 `skills-lock.json` 會記錄來源與內容雜湊，但 `npx skills update -p` 會重新取得上游 Skill，可能覆寫本機修改。因此不得盲目自動更新，更不得用 `-y` 跳過所有檢查後直接宣稱完成。

## 更新步驟

1. 從 repository root 檢查：

   ```powershell
   git status --short
   git diff -- AGENTS.md skills-lock.json .agents/skills docs/agents/mattpocock-skills-local-adjustments.md
   ```

2. 依「階段 0.4」備份目前 Skills 與本機調整。
3. 讀取：

   ```text
   docs/agents/mattpocock-skills-local-adjustments.md
   ```

4. 列出上游目前可用 Skills：

   ```powershell
   npx --yes skills@latest add mattpocock/skills --list
   ```

5. 檢查上游 release／commit 與高風險 Skill 的變更。若 `implement`、`to-spec`、`to-tickets`、`setup-matt-pocock-skills`、`wayfinder`、`research`、`code-review` 或 `improve-codebase-architecture` 的流程語意已有重大改動，一次只問一題是否繼續更新。
6. 執行互動式專案更新，不使用全域旗標：

   ```powershell
   npx --yes skills@latest update -p
   ```

7. 立即執行：

   ```powershell
   git diff -- .agents/skills skills-lock.json
   ```

8. 依語意重新套用本文件的 8 項本機調整，不可用過期行號盲目套 patch。
9. 更新 `docs/agents/mattpocock-skills-local-adjustments.md` 的實際版本、ref、hash 與調整差異。
10. 重跑「階段 8」全部驗證。
11. 顯示結果；仍不得自動 commit 或 push。

---

# 回復與故障處理

## 安裝命令失敗

回報：

- 失敗命令。
- 退出狀態。
- 關鍵 stdout／stderr。
- `.agents/skills/` 與 `skills-lock.json` 是否部分建立。
- `git status --short`。

不得改成全域安裝作為繞過方式。

## Node.js 版本不足

一次只問一題是否允許升級 Node.js；建議安裝目前受支援且版本不低於 `22.20.0` 的 LTS。未核准前不得使用套件管理器修改系統。

## Windows symlink 或權限問題

本流程已指定 `--copy`。若仍出現權限錯誤，回報精確路徑與錯誤，不得要求關閉所有安全機制或改成管理員 Full Access 作為第一選項。

## Skills 安裝後未出現在桌面版

1. 確認 `.agents/skills/<name>/SKILL.md` 存在。
2. 確認 Codex 開啟的是同一 repository root。
3. 確認 `agents/openai.yaml` 存在。
4. 在同一專案開啟新工作階段；必要時重新啟動桌面應用程式。
5. 從 Skills 側邊欄確認，不得只依 CLI 語法判斷。

## 上游內容與本文件不一致

不要猜測。摘要差異、說明哪一項安全調整可能已過期，一次只問一題是否依新的上游設計調整本機規則。

## 需要回復

- 優先使用 Windows 暫存備份與 `git diff` 精準回復。
- 回復前列出要還原或刪除的精確檔案，一次只問一題取得核准。
- 不得使用 `git reset --hard`、`git clean` 或遞迴刪除整個 `.agents/`。

---

# 驗收條件

只有下列條件全部成立，才能回報「安裝完成」：

- [ ] 已確認 repository root。
- [ ] Git、Node.js `>=22.20.0`、npm、`npx` 均可用。
- [ ] 已先執行 `--list` 並確認 15 個 Skill 名稱仍存在。
- [ ] 15 個 Skill 已安裝到目前專案 `.agents/skills/`。
- [ ] 未使用 `-g`／`--global`。
- [ ] 每個 Skill 均有 `SKILL.md` 與 `agents/openai.yaml`。
- [ ] `skills-lock.json` 存在並已記錄實際來源資訊。
- [ ] 8 個高風險 Skill 已套用本機安全調整。
- [ ] `AGENTS.md` 已合併且標記區塊只有一份。
- [ ] 已建立或更新本機調整紀錄。
- [ ] 已執行檔案、內容、安全與 Git diff 驗證。
- [ ] 未自動 commit、push、建立 PR／Issue／分支或修改遠端狀態。
- [ ] 已如實回報 setup 是否完成；若需重啟／新工作階段，已提供精確提示詞。
- [ ] 完成報告包含命令、實際結果、未完成項目及風險。

---

# 附錄 A：對原「Matt Pocock Skills 快速實戰指南」的審核結論

## 可直接採用

1. 優先使用專案級 `.agents/skills/`，避免影響其他專案與全域設定。
2. 使用 `npx skills` 安裝 `mattpocock/skills`，並指定 Codex。
3. Windows 採 `--copy` 可降低 symlink 權限問題。
4. 安裝核心工程 Skills，而不是一次導入所有 personal、in-progress 或 deprecated Skills。
5. `implement` 的自動 commit 行為必須修改。
6. `CONTEXT.md`、規格、ADR 與 `AGENTS.md` 應分工，不應混成單一巨型文件。
7. 任務完成必須附驗證命令、結果與未解風險。
8. 新功能、Bug、重構與大型工作採不同 Skill 流程的方向合理。

## 已修正

1. **桌面版安裝前提**：Windows 桌面版 Codex 不需要先以 npm 安裝 Codex CLI；本流程只要求 Git、Node.js、npm 與 `npx`。
2. **Node.js 要求**：不能只寫模糊的「Node.js LTS」。審核時 `skills 1.5.20` 明確要求 Node.js `>=22.20.0`。
3. **桌面版呼叫方式**：桌面應用程式應先以 Skills 側邊欄確認；`/skills` 或 `$skill-name` 是 CLI／IDE 文件中的明確呼叫方式，不應當成桌面版唯一方法。
4. **setup 的檔案優先序**：審核版本在同時存在時會先修改 `CLAUDE.md`；這不符合本次 Codex 專案需求，因此本文件改為優先 `AGENTS.md` 並要求確認。
5. **setup 支援範圍**：目前上游除 GitHub／local 外，也支援 GitLab 與其他自訂 tracker；不得依舊指南限制理解。
6. **更新風險**：`npx skills update -p` 會重新取得上游內容，本機修改可能被覆寫；原指南需補上備份、差異審核與重新套用程序。

## 新增的重要防護

1. `to-spec` 原流程會在確認 test seam 後直接發布；新增完整草稿與外部發布的二階段核准。
2. `to-tickets` 的核准需明確涵蓋 Issue 數量、blocking、標籤及外部目標。
3. `wayfinder` 會建立／關閉 Issue、指派、設定 blocking、建立研究分支並啟動研究子代理；全部新增逐批核准閘門。
4. `research`、`code-review` 與部分架構流程假設有背景／平行子代理；新增同步／循序降級方案。
5. `improve-codebase-architecture` 原流程使用 Tailwind 與 Mermaid CDN；新增預設離線、自包含 HTML 要求。
6. 新增 `skills-lock.json` 的來源／hash 紀錄與供應鏈更新審查。
7. 新增 Windows 暫存備份、非破壞性回復與完整驗收條件。

## 未納入本文件的內容

原指南中的 OpenCode、Antigravity IDE／CLI 安裝方式不屬於本次「Windows 桌面版 Codex」任務範圍，因此本文件不以它們作為安裝或驗收依據。

---

# 附錄 B：專案工作流摘要

| 情境 | 建議流程 | 主要核准點 |
|---|---|---|
| 新功能 | `grill-with-docs` → `to-spec` → `to-tickets` → `implement` → `code-review` | 規格發布、Ticket 發布、版本控制操作 |
| 小型 Bug | `diagnosing-bugs` → `tdd` → `code-review` | 根因證據、實際修正、版本控制操作 |
| 重大重構 | `improve-codebase-architecture` → grilling／wayfinder → `to-spec` → `to-tickets` → `implement` | 報告候選、外部 Map／Issue、遷移 tickets、實作 |
| 大型未知工作 | `wayfinder` → research／prototype／grilling → `to-spec` → `to-tickets` | 每批 Issue／分支／背景作業及最後規格發布 |
| 純審核 | `code-review` 的 Standards／Spec 雙軸 | 固定比較點與規格來源；預設唯讀 |

---

# 附錄 C：資料來源

1. Matt Pocock Skills repository：<https://github.com/mattpocock/skills>
2. Matt Pocock Skills README：<https://github.com/mattpocock/skills/blob/main/README.md>
3. `setup-matt-pocock-skills`：<https://github.com/mattpocock/skills/blob/main/skills/engineering/setup-matt-pocock-skills/SKILL.md>
4. `implement`：<https://github.com/mattpocock/skills/blob/main/skills/engineering/implement/SKILL.md>
5. `to-spec`：<https://github.com/mattpocock/skills/blob/main/skills/engineering/to-spec/SKILL.md>
6. `to-tickets`：<https://github.com/mattpocock/skills/blob/main/skills/engineering/to-tickets/SKILL.md>
7. `wayfinder`：<https://github.com/mattpocock/skills/blob/main/skills/engineering/wayfinder/SKILL.md>
8. `research`：<https://github.com/mattpocock/skills/blob/main/skills/engineering/research/SKILL.md>
9. `code-review`：<https://github.com/mattpocock/skills/blob/main/skills/engineering/code-review/SKILL.md>
10. `improve-codebase-architecture`：<https://github.com/mattpocock/skills/blob/main/skills/engineering/improve-codebase-architecture/SKILL.md>
11. skills CLI repository：<https://github.com/vercel-labs/skills>
12. skills CLI README：<https://github.com/vercel-labs/skills/blob/main/README.md>
13. skills CLI package metadata：<https://github.com/vercel-labs/skills/blob/main/package.json>
14. OpenAI Codex Skills 文件：<https://developers.openai.com/codex/skills>
15. OpenAI Windows Codex 應用程式文件：<https://developers.openai.com/codex/app/windows>
16. 使用者提供的《Matt Pocock Skills 快速實戰指南》HTML，審核日期標示為 2026-07-25。

---

本文件是專案級執行規格，不會變更任何全域設定；上游版本更新後，應重新核對本機調整是否仍符合最新 Skill 行為。
