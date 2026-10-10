# 伴日 Our Days

兩個人一起記錄飲食、花費、運動的 Web App（PWA）。iPhone、Android、電腦用瀏覽器開啟即可，手機可以「加入主畫面」當成 App 使用。

- 前端：單一 `index.html`（不需要編譯）
- 資料庫、登入：Supabase
- 網址：GitHub Pages（免費、HTTPS）

## 第一次設定

### 1. Supabase
1. 建立專案，地區選 **Northeast Asia (Tokyo)**。
2. **SQL Editor → New query**，貼上 `supabase/schema.sql` 全部內容，按 **Run**。
3. **Authentication → Sign In / Providers**：關閉 **Allow new users to sign up**，只讓你們兩個人登入。
4. **Authentication → Users → Add user → Create new user**：替兩個人各建一個帳號，輸入 Email 和密碼，並勾選 **Auto Confirm User**。
5. **Project Settings → API**（或 **API Keys**）：複製 Project URL 和 publishable（anon public）key，填進 `config.js`。

### 2. GitHub Pages
1. 到 GitHub 的 repository → **Settings → Pages**。
2. **Source** 選 **Deploy from a branch**，Branch 選 **main**、資料夾選 **/ (root)**，按 **Save**。
3. 約 1 分鐘後，網址會顯示在同一頁，例如 `https://你的帳號.github.io/Banri/`。

### 3. 開始使用
1. 兩個人各自打開網址，用自己的帳號登入。
2. 其中一個人到「我們」頁，把**邀請碼**傳給另一半；另一半在「我們」頁輸入這組碼，按「配對」。
3. 兩個人各自到「我們」頁設定暱稱。
4. 手機加入主畫面：
   - **iPhone**：用 Safari 開啟 → 分享按鈕 → **加入主畫面**
   - **Android**：用 Chrome 開啟 → 右上角選單 → **加到主畫面**

## 更新程式後重新部署
1. 修改檔案，把 `sw.js` 第一行的 `VERSION` 數字加 1，例如 `banri-v1` 改成 `banri-v2`。
2. 把變更推上 GitHub 的 `main` 分支。
3. 等待約 1 分鐘，GitHub Pages 會自動更新。
4. 手機上的 App 關掉再打開兩次，就會換成新版。

## 資料與權限
- 沒登入的人看不到任何資料。
- 每一對只看得到自己的紀錄；邀請碼滿兩個人之後，別人就不能再加入。
- 每個人的偏好（例如上次用的付款方式）只有自己看得到。
- 刪除紀錄時會留下刪除標記，另一支手機同步時才知道要移除。
- 兩支手機大約每 20 秒同步一次，打開 App 或切回畫面時也會馬上同步。
- 沒有網路時會顯示上次同步的資料；這時新增的紀錄不會存進去，要等連上網路再記。

## 常見問題
- **忘記密碼**：到 Supabase **Authentication → Users**，點那個帳號 → **Send password recovery** 或直接重設密碼。
- **想換另一半配對**：目前要在 Supabase 的 SQL Editor 處理，請先備份資料。
