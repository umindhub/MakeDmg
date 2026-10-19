# MakeDmg

[English](../../README.md) | **Deutsch** | [Español](README_es.md) | [Français](README_fr.md) | [Italiano](README_it.md) | [日本語](README_ja.md) | [한국어](README_ko.md) | [Nederlands](README_nl.md) | [简体中文](README_zh-Hans.md) | [繁體中文](README_zh-Hant.md)

`makedmg` erstellt gestaltete macOS-Disk-Images aus einer JSON-Konfiguration: Hintergrundbild oder -farbe, Symbolanordnung, ein Link auf „Programme“ (Applications), ein Volume-Symbol, Codesignierung und Notarisierung.

Anders als Werkzeuge, die den Finder per AppleScript steuern, schreibt makedmg das Finder-Layout (`.DS_Store`) selbst. Während des Builds öffnet sich kein Finder-Fenster, daher läuft es auf Ihrem Mac genauso wie in CI.

## Schnellstart

```bash
makedmg init --app build/MyApp.app      # writes makedmg.json
makedmg preview -c makedmg.json         # renders preview-light.png / preview-dark.png
makedmg build -c makedmg.json --open    # builds the DMG and opens it
```

## Installation

Mit Homebrew:

```bash
brew install umindhub/tap/makedmg
```

Oder aus dem Quellcode bauen (Swift 6, macOS 13+):

```bash
git clone https://github.com/umindhub/MakeDmg.git && cd MakeDmg
swift build -c release --arch arm64 --arch x86_64
cp .build/apple/Products/Release/makedmg /usr/local/bin/
```

## Konfiguration

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

Relative Pfade werden relativ zum Ordner der Konfigurationsdatei aufgelöst. Ein JSON-Schema für die Autovervollständigung im Editor liegt unter [`schema/makedmg.schema.json`](../../schema/makedmg.schema.json).

| Schlüssel | Pflicht | Standard | Hinweise |
|---|---|---|---|
| `volumeName` | ja | | Fenstertitel und Volume-Name; kein `:` |
| `output` | ja | | Mit `build -o` überschreibbar |
| `format` | | `ULFO` | `UDZO`, `UDBZ`, `ULFO` (10.11+), `ULMO` (10.15+) |
| `filesystem` | | `HFS+` | `APFS` funktioniert vorerst nur mit Farbhintergründen |
| `window` | | 200, 120, 640×400 | Zusätzlich `showToolbar`, `showSidebar`, `showStatusBar`, `showPathBar` |
| `icon` | | 128, Text 16, unten | `labelPosition`: `bottom` oder `right` |
| `background` | | keiner | `{"color": "#RRGGBB"}` oder `{"image": "path"}` |
| `contents` | ja | | Dateien (`path`, optional `name`, `hideExtension`) oder `{"type": "applications"}` |
| `volumeIcon` | | | `.icns` |
| `sign.identity` | | | Signiert das DMG mit `codesign --timestamp` |
| `notarize.keychainProfile` | | | Erfordert `sign`; notarisiert und heftet das Ticket an (staple) |

### Koordinaten und Größen

- `window.x` / `window.y` sind die linke obere Ecke des Fensters auf dem Bildschirm. Der Finder speichert einen Ursprung unten links, daher rechnet makedmg anhand des Hauptbildschirms des bauenden Macs um.
- `window.width` / `window.height` beschreiben den gesamten Fensterrahmen inklusive Titelleiste. Unter macOS 26 belegen Titelleiste und Tableiste etwa 68 pt, sodass der sichtbare Inhaltsbereich eines 600×400-Fensters etwa 600×332 beträgt. Berücksichtigen Sie das bei der Größe der Hintergrundgrafik.
- `contents[].x` / `y` sind Symbolmittelpunkte, gemessen von der linken oberen Ecke des Inhaltsbereichs.
- Der Finder zeichnet Dateinamen auf eigenen Hintergründen schwarz, im hellen wie im dunklen Modus. Sehr dunkle Hintergrundfarben machen sie schwer lesbar; `validate` warnt davor.

### Retina-Hintergründe

Legen Sie entweder `background@2x.png` (exakt doppelte Größe) neben `background.png`, das makedmg mit `tiffutil` zu einem TIFF mit mehreren Auflösungen zusammenführt, oder verwenden Sie ein einzelnes Bild, das mit 144 dpi oder mehr gespeichert ist. Der Finder zeichnet Hintergründe in Punktgröße (Pixel × 72 / dpi).

## Signierung und Notarisierung

Notarisierungs-Zugangsdaten einmalig speichern:

```bash
xcrun notarytool store-credentials notary \
  --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
```

Danach `sign.identity` und `notarize.keychainProfile` setzen. `build` signiert, reicht ein, wartet, heftet das Ticket an und führt eine Gatekeeper-Prüfung durch. Lehnt Apple die Einreichung ab, wird das Notarisierungsprotokoll ausgegeben. Für lokale Test-Builds `--skip-sign` oder `--skip-notarize` verwenden.

## Befehle

| Befehl | Zweck |
|---|---|
| `init [--app X.app] [-o file]` | Startkonfiguration schreiben |
| `validate -c file [--strict]` | Pfade, Wertebereiche und Layout prüfen; `--strict` schlägt bei Warnungen fehl |
| `preview -c file [--appearance light\|dark\|both]` | Fenster als PNG rendern, ohne zu bauen |
| `build -c file [-o out.dmg] [--open]` | Bauen, signieren, notarisieren |
| `inspect file.dmg \| .DS_Store` | Wurzeleinträge und Finder-Datensätze eines DMG anzeigen |

Mit `-v` / `--verbose` sehen Sie jeden Befehl, den makedmg ausführt.

## Funktionsweise

1. Mit `hdiutil create` ein beschreibbares Image erstellen, dessen Größe sich nach dem Inhalt richtet.
2. Mit `-nobrowse` mounten, damit der Finder es nie anzeigt.
3. Objekte mit `ditto` kopieren (erhält Signaturen und erweiterte Attribute), dann den Applications-Link, den versteckten Ordner `.background` und das Volume-Symbol hinzufügen.
4. `.DS_Store` direkt schreiben: Fenstereinstellungen, Optionen der Symbolansicht, Alias und Bookmark des Hintergrunds, Symbolpositionen.
5. Aushängen, in das komprimierte Format konvertieren, dann signieren, notarisieren und das Ticket anheften.

## Einschränkungen

- Bildhintergründe benötigen ein HFS+-Image (das APFS-Aliasformat ist noch nicht verifiziert).
- In den einzelnen `.DS_Store`-Knoten, den makedmg schreibt, passen etwa 30 Objekte.
- Die vertikale Fensterposition hängt von der Bildschirmhöhe des bauenden Macs ab.
- Apps unter `/System` lassen sich nicht kopieren (geschützte Datei-Flags); verpacken Sie Ihre eigene App.

## Lizenz

MakeDmg steht unter der [GNU Affero General Public License v3.0](../../LICENSE).
