# MakeDmg

**English** | [Deutsch](docs/i18n/README_de.md) | [Español](docs/i18n/README_es.md) | [Français](docs/i18n/README_fr.md) | [Italiano](docs/i18n/README_it.md) | [日本語](docs/i18n/README_ja.md) | [한국어](docs/i18n/README_ko.md) | [Nederlands](docs/i18n/README_nl.md) | [简体中文](docs/i18n/README_zh-Hans.md) | [繁體中文](docs/i18n/README_zh-Hant.md)

`makedmg` builds styled macOS disk images from a JSON config: background image or color,
icon layout, an Applications link, a volume icon, code signing and notarization.

Unlike tools that script Finder through AppleScript, makedmg writes the Finder layout
(`.DS_Store`) itself. No Finder window opens during the build, so it runs the same on
your Mac and on CI.

## Quick start

```bash
makedmg init --app build/MyApp.app      # writes makedmg.json
makedmg preview -c makedmg.json         # renders preview-light.png / preview-dark.png
makedmg build -c makedmg.json --open    # builds the DMG and opens it
```

## Install

With Homebrew:

```bash
brew install umindhub/tap/makedmg
```

Or build from source (Swift 6, macOS 13+):

```bash
git clone https://github.com/umindhub/MakeDmg.git && cd MakeDmg
swift build -c release --arch arm64 --arch x86_64
cp .build/apple/Products/Release/makedmg /usr/local/bin/
```

## Config

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

Relative paths are resolved against the folder of the config file. A JSON Schema for
editor completion lives in [`schema/makedmg.schema.json`](schema/makedmg.schema.json).

| Key | Required | Default | Notes |
|---|---|---|---|
| `volumeName` | yes | | Window title and volume name; no `:` |
| `output` | yes | | Overridable with `build -o` |
| `format` | | `ULFO` | `UDZO`, `UDBZ`, `ULFO` (10.11+), `ULMO` (10.15+) |
| `filesystem` | | `HFS+` | `APFS` works with color backgrounds only, for now |
| `window` | | 200, 120, 640×400 | Plus `showToolbar`, `showSidebar`, `showStatusBar`, `showPathBar` |
| `icon` | | 128, text 16, bottom | `labelPosition`: `bottom` or `right` |
| `background` | | none | `{"color": "#RRGGBB"}` or `{"image": "path"}` |
| `contents` | yes | | Files (`path`, optional `name`, `hideExtension`) or `{"type": "applications"}` |
| `volumeIcon` | | | `.icns` |
| `sign.identity` | | | Signs the DMG with `codesign --timestamp` |
| `notarize.keychainProfile` | | | Requires `sign`; notarizes and staples |

### Coordinates and sizes

- `window.x` / `window.y` are the window's top-left corner on screen. Finder stores a
  bottom-left origin, so makedmg converts using the main display of the building Mac.
- `window.width` / `window.height` are the whole window frame, title bar included. On
  macOS 26 the title bar plus tab bar take about 68 pt, so the visible content area of a
  600×400 window is about 600×332. Size background artwork with that in mind.
- `contents[].x` / `y` are icon centers, measured from the top-left of the content area.
- Finder draws file names in black on custom backgrounds, in both Light and Dark Mode.
  Very dark background colors make them hard to read; `validate` warns about this.

### Retina backgrounds

Either put `background@2x.png` (exactly twice the size) next to `background.png`, which
makedmg merges into a multi-resolution TIFF with `tiffutil`, or use a single image saved
at 144 dpi or more. Finder draws backgrounds at point size (pixels × 72 / dpi).

## Signing and notarization

Store notary credentials once:

```bash
xcrun notarytool store-credentials notary \
  --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
```

Then set `sign.identity` and `notarize.keychainProfile`. `build` signs, submits, waits,
staples, and runs a Gatekeeper assessment. If Apple rejects the submission the notary log
is printed. Use `--skip-sign` or `--skip-notarize` for local test builds.

## Commands

| Command | Purpose |
|---|---|
| `init [--app X.app] [-o file]` | Write a starter config |
| `validate -c file [--strict]` | Check paths, ranges, layout; `--strict` fails on warnings |
| `preview -c file [--appearance light\|dark\|both]` | Render the window to PNG without building |
| `build -c file [-o out.dmg] [--open]` | Build, sign, notarize |
| `inspect file.dmg \| .DS_Store` | Show root entries and Finder records of a DMG |

Add `-v` / `--verbose` to see every command makedmg runs.

## How it works

1. `hdiutil create` a read-write image sized from the payload.
2. Mount it with `-nobrowse`, so Finder never shows it.
3. Copy items with `ditto` (preserves signatures and extended attributes), add the
   Applications link, the hidden `.background` folder and the volume icon.
4. Write `.DS_Store` directly: window settings, icon view options, the background alias
   and bookmark, icon positions.
5. Detach, convert to the compressed format, then sign, notarize and staple.

## Limitations

- Image backgrounds need an HFS+ image (the APFS alias format is not verified yet).
- About 30 items fit in the single `.DS_Store` node makedmg writes.
- The window's vertical position depends on the screen height of the building Mac.
- Apps under `/System` cannot be copied (protected file flags); package your own app.

## License

MakeDmg is licensed under the [GNU Affero General Public License v3.0](LICENSE).
