# MakeDmg

[English](../../README.md) | [Deutsch](README_de.md) | [Español](README_es.md) | [Français](README_fr.md) | **Italiano** | [日本語](README_ja.md) | [한국어](README_ko.md) | [Nederlands](README_nl.md) | [简体中文](README_zh-Hans.md) | [繁體中文](README_zh-Hant.md)

`makedmg` crea immagini disco macOS personalizzate a partire da una configurazione JSON: immagine o colore di sfondo, disposizione delle icone, un collegamento ad Applicazioni, un’icona del volume, firma del codice e notarizzazione.

A differenza degli strumenti che controllano il Finder tramite AppleScript, makedmg scrive da sé il layout del Finder (`.DS_Store`). Durante la build non si apre alcuna finestra del Finder, quindi funziona allo stesso modo sul tuo Mac e in CI.

## Avvio rapido

```bash
makedmg init --app build/MyApp.app      # writes makedmg.json
makedmg preview -c makedmg.json         # renders preview-light.png / preview-dark.png
makedmg build -c makedmg.json --open    # builds the DMG and opens it
```

## Installazione

Con Homebrew:

```bash
brew install umindhub/tap/makedmg
```

Oppure compila dai sorgenti (Swift 6, macOS 13+):

```bash
git clone https://github.com/umindhub/MakeDmg.git && cd MakeDmg
swift build -c release --arch arm64 --arch x86_64
cp .build/apple/Products/Release/makedmg /usr/local/bin/
```

## Configurazione

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

I percorsi relativi vengono risolti rispetto alla cartella del file di configurazione. Uno JSON Schema per il completamento automatico nell’editor si trova in [`schema/makedmg.schema.json`](../../schema/makedmg.schema.json).

| Chiave | Obbligatorio | Predefinito | Note |
|---|---|---|---|
| `volumeName` | sì | | Titolo della finestra e nome del volume; niente `:` |
| `output` | sì | | Sovrascrivibile con `build -o` |
| `format` | | `ULFO` | `UDZO`, `UDBZ`, `ULFO` (10.11+), `ULMO` (10.15+) |
| `filesystem` | | `HFS+` | Per ora `APFS` funziona solo con sfondi a tinta unita |
| `window` | | 200, 120, 640×400 | Più `showToolbar`, `showSidebar`, `showStatusBar`, `showPathBar` |
| `icon` | | 128, testo 16, in basso | `labelPosition`: `bottom` o `right` |
| `background` | | nessuno | `{"color": "#RRGGBB"}` o `{"image": "path"}` |
| `contents` | sì | | File (`path`, `name` facoltativo, `hideExtension`) o `{"type": "applications"}` |
| `volumeIcon` | | | `.icns` |
| `sign.identity` | | | Firma il DMG con `codesign --timestamp` |
| `notarize.keychainProfile` | | | Richiede `sign`; esegue notarizzazione e staple del ticket |

### Coordinate e dimensioni

- `window.x` / `window.y` sono l’angolo in alto a sinistra della finestra sullo schermo. Il Finder memorizza un’origine in basso a sinistra, quindi makedmg converte usando lo schermo principale del Mac che esegue la build.
- `window.width` / `window.height` sono l’intera cornice della finestra, barra del titolo inclusa. Su macOS 26 la barra del titolo e la barra dei pannelli occupano circa 68 pt, quindi l’area di contenuto visibile di una finestra 600×400 è di circa 600×332. Tienine conto quando dimensioni l’immagine di sfondo.
- `contents[].x` / `y` sono i centri delle icone, misurati dall’angolo in alto a sinistra dell’area di contenuto.
- Il Finder disegna i nomi dei file in nero sugli sfondi personalizzati, sia in modalità chiara sia in modalità scura. Colori di sfondo molto scuri li rendono difficili da leggere; `validate` lo segnala con un avviso.

### Sfondi Retina

Metti `background@2x.png` (esattamente il doppio delle dimensioni) accanto a `background.png`, che makedmg unisce in un TIFF multirisoluzione con `tiffutil`, oppure usa una singola immagine salvata a 144 dpi o più. Il Finder disegna gli sfondi in punti (pixel × 72 / dpi).

## Firma e notarizzazione

Salva una sola volta le credenziali per la notarizzazione:

```bash
xcrun notarytool store-credentials notary \
  --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
```

Poi imposta `sign.identity` e `notarize.keychainProfile`. `build` firma, invia, attende, esegue lo staple e avvia una verifica Gatekeeper. Se Apple rifiuta l’invio, viene stampato il log della notarizzazione. Usa `--skip-sign` o `--skip-notarize` per le build di test locali.

## Comandi

| Comando | Scopo |
|---|---|
| `init [--app X.app] [-o file]` | Scrive una configurazione iniziale |
| `validate -c file [--strict]` | Controlla percorsi, intervalli e layout; `--strict` fallisce in presenza di avvisi |
| `preview -c file [--appearance light\|dark\|both]` | Esegue il rendering della finestra in PNG senza fare la build |
| `build -c file [-o out.dmg] [--open]` | Esegue build, firma e notarizzazione |
| `inspect file.dmg \| .DS_Store` | Mostra le voci radice e i record del Finder di un DMG |

Aggiungi `-v` / `--verbose` per vedere ogni comando eseguito da makedmg.

## Come funziona

1. Crea con `hdiutil create` un’immagine in lettura/scrittura dimensionata in base al contenuto.
2. La monta con `-nobrowse`, così il Finder non la mostra mai.
3. Copia gli elementi con `ditto` (preserva firme e attributi estesi), poi aggiunge il collegamento ad Applicazioni, la cartella nascosta `.background` e l’icona del volume.
4. Scrive direttamente `.DS_Store`: impostazioni della finestra, opzioni della vista a icone, alias e bookmark dello sfondo, posizioni delle icone.
5. Smonta, converte nel formato compresso, poi firma, notarizza ed esegue lo staple.

## Limitazioni

- Gli sfondi con immagine richiedono un’immagine HFS+ (il formato alias di APFS non è ancora verificato).
- Nel singolo nodo `.DS_Store` scritto da makedmg entrano circa 30 elementi.
- La posizione verticale della finestra dipende dall’altezza dello schermo del Mac che esegue la build.
- Le app sotto `/System` non possono essere copiate (flag di file protetti); impacchetta la tua app.

## Licenza

MakeDmg è distribuito con licenza [GNU Affero General Public License v3.0](../../LICENSE).
