# MakeDmg

[English](../../README.md) | [Deutsch](README_de.md) | [Español](README_es.md) | [Français](README_fr.md) | [Italiano](README_it.md) | **日本語** | [한국어](README_ko.md) | [Nederlands](README_nl.md) | [简体中文](README_zh-Hans.md) | [繁體中文](README_zh-Hant.md)

`makedmg` は JSON 設定からスタイル付きの macOS ディスクイメージを作成します。背景画像または背景色、アイコン配置、Applications へのリンク、ボリュームアイコン、コード署名、公証に対応しています。

AppleScript で Finder を操作するツールとは異なり、makedmg は Finder のレイアウト（`.DS_Store`）を自ら書き込みます。ビルド中に Finder ウインドウが開くことはないため、手元の Mac でも CI でも同じように動作します。

## クイックスタート

```bash
makedmg init --app build/MyApp.app      # writes makedmg.json
makedmg preview -c makedmg.json         # renders preview-light.png / preview-dark.png
makedmg build -c makedmg.json --open    # builds the DMG and opens it
```

## インストール

Homebrew の場合：

```bash
brew install umindhub/tap/makedmg
```

またはソースからビルド（Swift 6、macOS 13 以降）：

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

相対パスは設定ファイルのあるフォルダを基準に解決されます。エディタ補完用の JSON Schema は [`schema/makedmg.schema.json`](../../schema/makedmg.schema.json) にあります。

| キー | 必須 | デフォルト | 備考 |
|---|---|---|---|
| `volumeName` | はい | | ウインドウタイトルおよびボリューム名。`:` は使用不可 |
| `output` | はい | | `build -o` で上書き可能 |
| `format` | | `ULFO` | `UDZO`, `UDBZ`, `ULFO` (10.11+), `ULMO` (10.15+) |
| `filesystem` | | `HFS+` | 現時点では `APFS` は背景色の場合のみ使用可能 |
| `window` | | 200, 120, 640×400 | ほかに `showToolbar`、`showSidebar`、`showStatusBar`、`showPathBar` |
| `icon` | | 128、テキスト 16、下 | `labelPosition`：`bottom` または `right` |
| `background` | | なし | `{"color": "#RRGGBB"}` または `{"image": "path"}` |
| `contents` | はい | | ファイル（`path`、任意の `name`、`hideExtension`）または `{"type": "applications"}` |
| `volumeIcon` | | | `.icns` |
| `sign.identity` | | | `codesign --timestamp` で DMG に署名 |
| `notarize.keychainProfile` | | | `sign` が必要。公証してチケットをステープル |

### 座標とサイズ

- `window.x` / `window.y` は画面上のウインドウ左上の座標です。Finder は左下を原点として保存するため、makedmg はビルドする Mac のメインディスプレイを基準に変換します。
- `window.width` / `window.height` はタイトルバーを含むウインドウ全体のフレームです。macOS 26 ではタイトルバーとタブバーで約 68 pt を占めるため、600×400 のウインドウで実際に見えるコンテンツ領域は約 600×332 になります。背景画像のサイズはこれを考慮して決めてください。
- `contents[].x` / `y` はアイコンの中心座標で、コンテンツ領域の左上から測ります。
- カスタム背景の上では、Finder はライトモードでもダークモードでもファイル名を黒で描画します。背景色が非常に暗いと読みにくくなるため、`validate` が警告します。

### Retina 対応の背景

`background.png` と同じ場所に `background@2x.png`（ちょうど 2 倍のサイズ）を置くと、makedmg が `tiffutil` でマルチ解像度の TIFF に結合します。あるいは 144 dpi 以上で保存した画像を 1 枚だけ使うこともできます。Finder は背景をポイントサイズ（ピクセル × 72 / dpi）で描画します。

## 署名と公証

公証用の認証情報を一度だけ保存します：

```bash
xcrun notarytool store-credentials notary \
  --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
```

そのうえで `sign.identity` と `notarize.keychainProfile` を設定します。`build` は署名、提出、完了待ち、ステープルを行い、Gatekeeper による評価を実行します。Apple に却下された場合は公証ログが出力されます。ローカルでのテストビルドには `--skip-sign` または `--skip-notarize` を使ってください。

## コマンド

| コマンド | 用途 |
|---|---|
| `init [--app X.app] [-o file]` | 初期設定ファイルを書き出す |
| `validate -c file [--strict]` | パス、値の範囲、レイアウトを検査。`--strict` では警告でも失敗 |
| `preview -c file [--appearance light\|dark\|both]` | ビルドせずにウインドウを PNG にレンダリング |
| `build -c file [-o out.dmg] [--open]` | ビルド、署名、公証 |
| `inspect file.dmg \| .DS_Store` | DMG のルート項目と Finder レコードを表示 |

`-v` / `--verbose` を付けると、makedmg が実行するすべてのコマンドを表示します。

## 仕組み

1. `hdiutil create` で、内容に合わせたサイズの読み書き可能なイメージを作成します。
2. `-nobrowse` 付きでマウントするため、Finder に表示されることはありません。
3. `ditto` で項目をコピーし（署名と拡張属性を保持）、Applications へのリンク、隠しフォルダ `.background`、ボリュームアイコンを追加します。
4. `.DS_Store` を直接書き込みます：ウインドウ設定、アイコン表示オプション、背景のエイリアスとブックマーク、アイコン位置。
5. デタッチして圧縮形式に変換し、署名、公証、ステープルを行います。

## 制限事項

- 背景画像を使う場合は HFS+ イメージが必要です（APFS のエイリアス形式はまだ検証されていません）。
- makedmg が書き込む単一の `.DS_Store` ノードに収まる項目は約 30 個です。
- ウインドウの縦位置は、ビルドする Mac の画面の高さに依存します。
- `/System` 配下のアプリはコピーできません（保護されたファイルフラグのため）。自分のアプリをパッケージしてください。

## ライセンス

MakeDmg は [GNU Affero General Public License v3.0](../../LICENSE) の下でライセンスされています。
