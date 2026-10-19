# MakeDmg

[English](../../README.md) | [Deutsch](README_de.md) | [Español](README_es.md) | [Français](README_fr.md) | [Italiano](README_it.md) | [日本語](README_ja.md) | [한국어](README_ko.md) | **Nederlands** | [简体中文](README_zh-Hans.md) | [繁體中文](README_zh-Hant.md)

`makedmg` bouwt opgemaakte macOS-schijfkopieën op basis van een JSON-configuratie: achtergrondafbeelding of -kleur, indeling van symbolen, een koppeling naar Programma’s, een volumesymbool, codesignering en notarisatie.

Anders dan tools die de Finder via AppleScript aansturen, schrijft makedmg de Finder-indeling (`.DS_Store`) zelf. Tijdens het bouwen gaat er geen Finder-venster open, dus het werkt op je Mac precies zoals in CI.

## Snel aan de slag

```bash
makedmg init --app build/MyApp.app      # writes makedmg.json
makedmg preview -c makedmg.json         # renders preview-light.png / preview-dark.png
makedmg build -c makedmg.json --open    # builds the DMG and opens it
```

## Installatie

Met Homebrew:

```bash
brew install umindhub/tap/makedmg
```

Of bouw vanuit de broncode (Swift 6, macOS 13+):

```bash
git clone https://github.com/umindhub/MakeDmg.git && cd MakeDmg
swift build -c release --arch arm64 --arch x86_64
cp .build/apple/Products/Release/makedmg /usr/local/bin/
```

## Configuratie

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

Relatieve paden worden opgelost ten opzichte van de map van het configuratiebestand. Een JSON Schema voor automatisch aanvullen in de editor staat in [`schema/makedmg.schema.json`](../../schema/makedmg.schema.json).

| Sleutel | Verplicht | Standaard | Opmerkingen |
|---|---|---|---|
| `volumeName` | ja | | Venstertitel en volumenaam; geen `:` |
| `output` | ja | | Te overschrijven met `build -o` |
| `format` | | `ULFO` | `UDZO`, `UDBZ`, `ULFO` (10.11+), `ULMO` (10.15+) |
| `filesystem` | | `HFS+` | `APFS` werkt voorlopig alleen met kleurachtergronden |
| `window` | | 200, 120, 640×400 | Plus `showToolbar`, `showSidebar`, `showStatusBar`, `showPathBar` |
| `icon` | | 128, tekst 16, onder | `labelPosition`: `bottom` of `right` |
| `background` | | geen | `{"color": "#RRGGBB"}` of `{"image": "path"}` |
| `contents` | ja | | Bestanden (`path`, optioneel `name`, `hideExtension`) of `{"type": "applications"}` |
| `volumeIcon` | | | `.icns` |
| `sign.identity` | | | Signeert de DMG met `codesign --timestamp` |
| `notarize.keychainProfile` | | | Vereist `sign`; notariseert en voegt het ticket toe (staple) |

### Coördinaten en afmetingen

- `window.x` / `window.y` zijn de linkerbovenhoek van het venster op het scherm. De Finder slaat een oorsprong linksonder op, dus makedmg rekent om op basis van het hoofdscherm van de Mac die bouwt.
- `window.width` / `window.height` zijn het volledige vensterkader, inclusief titelbalk. In macOS 26 nemen de titelbalk en tabbalk samen ongeveer 68 pt in beslag, dus het zichtbare inhoudsgebied van een venster van 600×400 is ongeveer 600×332. Houd daar rekening mee bij het formaat van de achtergrondafbeelding.
- `contents[].x` / `y` zijn de middelpunten van de symbolen, gemeten vanaf de linkerbovenhoek van het inhoudsgebied.
- De Finder tekent bestandsnamen in het zwart op aangepaste achtergronden, zowel in de lichte als in de donkere modus. Zeer donkere achtergrondkleuren maken ze slecht leesbaar; `validate` waarschuwt hiervoor.

### Retina-achtergronden

Zet `background@2x.png` (precies twee keer zo groot) naast `background.png`, waarna makedmg ze met `tiffutil` samenvoegt tot een TIFF met meerdere resoluties, of gebruik één afbeelding die is opgeslagen met 144 dpi of meer. De Finder tekent achtergronden op puntformaat (pixels × 72 / dpi).

## Signeren en notariseren

Sla de notarisatiegegevens één keer op:

```bash
xcrun notarytool store-credentials notary \
  --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
```

Stel daarna `sign.identity` en `notarize.keychainProfile` in. `build` signeert, dient in, wacht, voegt het ticket toe en voert een Gatekeeper-controle uit. Als Apple de inzending afwijst, wordt het notarisatielogboek getoond. Gebruik `--skip-sign` of `--skip-notarize` voor lokale testbuilds.

## Opdrachten

| Opdracht | Doel |
|---|---|
| `init [--app X.app] [-o file]` | Schrijft een startconfiguratie |
| `validate -c file [--strict]` | Controleert paden, waardebereiken en indeling; `--strict` faalt bij waarschuwingen |
| `preview -c file [--appearance light\|dark\|both]` | Rendert het venster naar PNG zonder te bouwen |
| `build -c file [-o out.dmg] [--open]` | Bouwt, signeert en notariseert |
| `inspect file.dmg \| .DS_Store` | Toont de hoofditems en Finder-records van een DMG |

Voeg `-v` / `--verbose` toe om elke opdracht te zien die makedmg uitvoert.

## Hoe het werkt

1. Met `hdiutil create` een beschrijfbare schijfkopie maken, afgestemd op de grootte van de inhoud.
2. Koppelen met `-nobrowse`, zodat de Finder hem nooit toont.
3. Onderdelen kopiëren met `ditto` (behoudt handtekeningen en uitgebreide attributen) en de Applications-koppeling, de verborgen map `.background` en het volumesymbool toevoegen.
4. `.DS_Store` direct schrijven: vensterinstellingen, opties voor symboolweergave, de alias en bookmark van de achtergrond, symboolposities.
5. Ontkoppelen, converteren naar het gecomprimeerde formaat en vervolgens signeren, notariseren en het ticket toevoegen.

## Beperkingen

- Afbeeldingsachtergronden vereisen een HFS+-schijfkopie (het APFS-aliasformaat is nog niet geverifieerd).
- In het enkele `.DS_Store`-knooppunt dat makedmg schrijft passen ongeveer 30 onderdelen.
- De verticale positie van het venster hangt af van de schermhoogte van de Mac die bouwt.
- Apps onder `/System` kunnen niet worden gekopieerd (beschermde bestandsvlaggen); verpak je eigen app.

## Licentie

MakeDmg valt onder de [GNU Affero General Public License v3.0](../../LICENSE).
