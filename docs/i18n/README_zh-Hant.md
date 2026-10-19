# MakeDmg

[English](../../README.md) | [Deutsch](README_de.md) | [Español](README_es.md) | [Français](README_fr.md) | [Italiano](README_it.md) | [日本語](README_ja.md) | [한국어](README_ko.md) | [Nederlands](README_nl.md) | [简体中文](README_zh-Hans.md) | **繁體中文**

`makedmg` 依據 JSON 設定建立帶樣式的 macOS 磁碟映像檔：背景圖片或背景色、圖示配置、Applications 連結、卷宗圖示、程式碼簽署與公證。

與透過 AppleScript 操控 Finder 的工具不同，makedmg 會自行寫入 Finder 版面配置（`.DS_Store`）。建置過程中不會開啟任何 Finder 視窗，因此在你的 Mac 上與 CI 中執行結果完全一致。

## 快速開始

```bash
makedmg init --app build/MyApp.app      # writes makedmg.json
makedmg preview -c makedmg.json         # renders preview-light.png / preview-dark.png
makedmg build -c makedmg.json --open    # builds the DMG and opens it
```

## 安裝

使用 Homebrew：

```bash
brew install umindhub/tap/makedmg
```

或從原始碼建置（Swift 6，macOS 13+）：

```bash
git clone https://github.com/umindhub/MakeDmg.git && cd MakeDmg
swift build -c release --arch arm64 --arch x86_64
cp .build/apple/Products/Release/makedmg /usr/local/bin/
```

## 設定

```json
{
  "volumeName": "MyApp",
  "output": "build/MyApp.dmg",
  "format": "ULFO",
  "window": { "x": 200, "y": 120, "width": 600, "height": 400 },
  "icon": { "size": 128, "textSize": 16 },
  "background": { "image": "assets/background.png" },
  "contents": [
    { "path": "build/MyApp.app", "x": 150, "y": 150, "hideExtension": true },
    { "type": "applications", "x": 450, "y": 150 }
  ],
  "volumeIcon": "assets/volume.icns",
  "sign": { "identity": "Developer ID Application: Your Name (TEAMID)" },
  "notarize": { "keychainProfile": "notary" }
}
```

相對路徑以設定檔所在資料夾為基準解析。供編輯器自動完成使用的 JSON Schema 位於 [`schema/makedmg.schema.json`](../../schema/makedmg.schema.json)。

| 鍵 | 必填 | 預設值 | 說明 |
|---|---|---|---|
| `volumeName` | 是 | | 視窗標題與卷宗名稱；不可包含 `:` |
| `output` | 是 | | 可用 `build -o` 覆寫 |
| `format` | | `ULFO` | `UDZO`, `UDBZ`, `ULFO` (10.11+), `ULMO` (10.15+) |
| `filesystem` | | `HFS+` | 目前 `APFS` 僅支援純色背景 |
| `window` | | 200, 120, 640×400 | 另有 `showToolbar`、`showSidebar`、`showStatusBar`、`showPathBar` |
| `icon` | | 128，文字 16，底部 | `labelPosition`：`bottom` 或 `right` |
| `background` | | 無 | `{"color": "#RRGGBB"}` 或 `{"image": "path"}` |
| `contents` | 是 | | 檔案（`path`、選用的 `name`、`hideExtension`）或 `{"type": "applications"}` |
| `volumeIcon` | | | `.icns` |
| `sign.identity` | | | 使用 `codesign --timestamp` 簽署 DMG |
| `notarize.keychainProfile` | | | 需要 `sign`；完成公證並裝訂（staple）票證 |

### 座標與尺寸

- `window.x` / `window.y` 是視窗在螢幕上的左上角座標。Finder 儲存的是左下角原點，因此 makedmg 會依建置用 Mac 的主顯示器進行換算。
- `window.width` / `window.height` 是整個視窗框架，包含標題列。在 macOS 26 上，標題列加標籤列約佔 68 pt，所以 600×400 視窗的可見內容區域約為 600×332。設計背景圖尺寸時請將此納入考量。
- `contents[].x` / `y` 是圖示中心座標，從內容區域左上角起算。
- 在自訂背景上，Finder 無論淺色或深色模式都以黑色繪製檔名。背景色過深會使文字難以辨識，`validate` 會對此發出警告。

### Retina 背景

可以在 `background.png` 旁放一張 `background@2x.png`（尺寸正好兩倍），makedmg 會用 `tiffutil` 將兩者合併為多解析度 TIFF；也可以只用一張以 144 dpi 以上解析度儲存的圖片。Finder 以點尺寸（像素 × 72 / dpi）繪製背景。

## 簽署與公證

先儲存一次公證憑證：

```bash
xcrun notarytool store-credentials notary \
  --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
```

接著設定 `sign.identity` 與 `notarize.keychainProfile`。`build` 會依序簽署、提交、等待、裝訂票證，並執行 Gatekeeper 評估。如果 Apple 拒絕提交，會輸出公證日誌。本機測試建置可使用 `--skip-sign` 或 `--skip-notarize`。

## 指令

| 指令 | 用途 |
|---|---|
| `init [--app X.app] [-o file]` | 寫入初始設定 |
| `validate -c file [--strict]` | 檢查路徑、數值範圍與版面配置；`--strict` 遇到警告也會失敗 |
| `preview -c file [--appearance light\|dark\|both]` | 不建置，直接將視窗算繪為 PNG |
| `build -c file [-o out.dmg] [--open]` | 建置、簽署、公證 |
| `inspect file.dmg \| .DS_Store` | 顯示 DMG 的根目錄項目與 Finder 記錄 |

加上 `-v` / `--verbose` 可查看 makedmg 執行的每一道指令。

## 運作原理

1. 以 `hdiutil create` 依內容大小建立可讀寫的映像檔。
2. 以 `-nobrowse` 掛載，Finder 永遠不會顯示它。
3. 以 `ditto` 複製項目（保留簽章與延伸屬性），並加入 Applications 連結、隱藏的 `.background` 資料夾與卷宗圖示。
4. 直接寫入 `.DS_Store`：視窗設定、圖示顯示方式選項、背景的替身與書籤、圖示位置。
5. 退出後轉換為壓縮格式，接著簽署、公證並裝訂票證。

## 限制

- 圖片背景需要 HFS+ 映像檔（APFS 替身格式尚未驗證）。
- makedmg 寫入的單一 `.DS_Store` 節點約可容納 30 個項目。
- 視窗的垂直位置取決於建置用 Mac 的螢幕高度。
- `/System` 下的 App 無法複製（受保護的檔案旗標）；請封裝你自己的 App。

## 授權

MakeDmg 採用 [GNU Affero General Public License v3.0](../../LICENSE) 授權。
