# MakeDmg

[English](../../README.md) | [Deutsch](README_de.md) | [Español](README_es.md) | [Français](README_fr.md) | [Italiano](README_it.md) | [日本語](README_ja.md) | [한국어](README_ko.md) | [Nederlands](README_nl.md) | **简体中文** | [繁體中文](README_zh-Hant.md)

`makedmg` 根据 JSON 配置构建带样式的 macOS 磁盘映像：背景图片或背景色、图标布局、Applications 链接、卷图标、代码签名和公证。

与通过 AppleScript 操控 Finder 的工具不同，makedmg 自己写入 Finder 布局（`.DS_Store`）。构建过程中不会弹出任何 Finder 窗口，因此在你的 Mac 上和 CI 中运行效果完全一致。

## 快速开始

```bash
makedmg init --app build/MyApp.app      # writes makedmg.json
makedmg preview -c makedmg.json         # renders preview-light.png / preview-dark.png
makedmg build -c makedmg.json --open    # builds the DMG and opens it
```

## 安装

使用 Homebrew：

```bash
brew install umindhub/tap/makedmg
```

或从源码构建（Swift 6，macOS 13+）：

```bash
git clone https://github.com/umindhub/MakeDmg.git && cd MakeDmg
swift build -c release --arch arm64 --arch x86_64
cp .build/apple/Products/Release/makedmg /usr/local/bin/
```

## 配置

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

相对路径以配置文件所在文件夹为基准解析。用于编辑器补全的 JSON Schema 位于 [`schema/makedmg.schema.json`](../../schema/makedmg.schema.json)。

| 键 | 必填 | 默认值 | 说明 |
|---|---|---|---|
| `volumeName` | 是 | | 窗口标题和卷名；不能包含 `:` |
| `output` | 是 | | 可用 `build -o` 覆盖 |
| `format` | | `ULFO` | `UDZO`, `UDBZ`, `ULFO` (10.11+), `ULMO` (10.15+) |
| `filesystem` | | `HFS+` | 目前 `APFS` 仅支持纯色背景 |
| `window` | | 200, 120, 640×400 | 另有 `showToolbar`、`showSidebar`、`showStatusBar`、`showPathBar` |
| `icon` | | 128，文字 16，底部 | `labelPosition`：`bottom` 或 `right` |
| `background` | | 无 | `{"color": "#RRGGBB"}` 或 `{"image": "path"}` |
| `contents` | 是 | | 文件（`path`、可选 `name`、`hideExtension`）或 `{"type": "applications"}` |
| `volumeIcon` | | | `.icns` |
| `sign.identity` | | | 使用 `codesign --timestamp` 为 DMG 签名 |
| `notarize.keychainProfile` | | | 需要 `sign`；完成公证并装订（staple）票据 |

### 坐标与尺寸

- `window.x` / `window.y` 是窗口在屏幕上的左上角坐标。Finder 存储的是左下角原点，因此 makedmg 会按构建所用 Mac 的主显示器进行换算。
- `window.width` / `window.height` 是整个窗口框架，包含标题栏。在 macOS 26 上，标题栏加标签栏约占 68 pt，所以 600×400 窗口的可见内容区域约为 600×332。设计背景图尺寸时请考虑这一点。
- `contents[].x` / `y` 是图标中心坐标，从内容区域左上角开始计算。
- 在自定义背景上，Finder 无论浅色还是深色模式都以黑色绘制文件名。背景色过深会导致文字难以辨认，`validate` 会对此给出警告。

### Retina 背景

可以在 `background.png` 旁放一张 `background@2x.png`（尺寸正好两倍），makedmg 会用 `tiffutil` 将它们合并为多分辨率 TIFF；也可以只用一张以 144 dpi 或更高分辨率保存的图片。Finder 按点尺寸（像素 × 72 / dpi）绘制背景。

## 签名与公证

先保存一次公证凭据：

```bash
xcrun notarytool store-credentials notary \
  --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
```

然后设置 `sign.identity` 和 `notarize.keychainProfile`。`build` 会依次签名、提交、等待、装订票据，并运行 Gatekeeper 评估。如果 Apple 拒绝提交，会打印公证日志。本地测试构建可使用 `--skip-sign` 或 `--skip-notarize`。

## 命令

| 命令 | 用途 |
|---|---|
| `init [--app X.app] [-o file]` | 写入初始配置 |
| `validate -c file [--strict]` | 检查路径、取值范围和布局；`--strict` 遇到警告也会失败 |
| `preview -c file [--appearance light\|dark\|both]` | 不构建，直接将窗口渲染为 PNG |
| `build -c file [-o out.dmg] [--open]` | 构建、签名、公证 |
| `inspect file.dmg \| .DS_Store` | 显示 DMG 的根目录条目和 Finder 记录 |

加上 `-v` / `--verbose` 可查看 makedmg 执行的每条命令。

## 工作原理

1. 用 `hdiutil create` 按内容大小创建可读写映像。
2. 以 `-nobrowse` 挂载，Finder 永远不会显示它。
3. 用 `ditto` 复制项目（保留签名和扩展属性），并添加 Applications 链接、隐藏的 `.background` 文件夹和卷图标。
4. 直接写入 `.DS_Store`：窗口设置、图标视图选项、背景的别名与书签、图标位置。
5. 卸载后转换为压缩格式，然后签名、公证并装订票据。

## 限制

- 图片背景需要 HFS+ 映像（APFS 别名格式尚未验证）。
- makedmg 写入的单个 `.DS_Store` 节点大约可容纳 30 个项目。
- 窗口的垂直位置取决于构建所用 Mac 的屏幕高度。
- `/System` 下的应用无法复制（受保护的文件标志）；请打包你自己的应用。

## 许可证

MakeDmg 采用 [GNU Affero General Public License v3.0](../../LICENSE) 许可。
