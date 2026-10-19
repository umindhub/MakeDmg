# MakeDmg

[English](../../README.md) | [Deutsch](README_de.md) | [Español](README_es.md) | **Français** | [Italiano](README_it.md) | [日本語](README_ja.md) | [한국어](README_ko.md) | [Nederlands](README_nl.md) | [简体中文](README_zh-Hans.md) | [繁體中文](README_zh-Hant.md)

`makedmg` crée des images disque macOS soignées à partir d’une configuration JSON : image ou couleur d’arrière-plan, disposition des icônes, lien vers Applications, icône de volume, signature du code et notarisation.

Contrairement aux outils qui pilotent le Finder via AppleScript, makedmg écrit lui-même la disposition du Finder (`.DS_Store`). Aucune fenêtre du Finder ne s’ouvre pendant la construction : l’outil fonctionne donc de la même manière sur votre Mac et en CI.

## Démarrage rapide

```bash
makedmg init --app build/MyApp.app      # writes makedmg.json
makedmg preview -c makedmg.json         # renders preview-light.png / preview-dark.png
makedmg build -c makedmg.json --open    # builds the DMG and opens it
```

## Installation

Avec Homebrew :

```bash
brew install umindhub/tap/makedmg
```

Ou compilez depuis les sources (Swift 6, macOS 13+) :

```bash
git clone https://github.com/umindhub/MakeDmg.git && cd MakeDmg
swift build -c release --arch arm64 --arch x86_64
cp .build/apple/Products/Release/makedmg /usr/local/bin/
```

## Configuration

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

Les chemins relatifs sont résolus par rapport au dossier du fichier de configuration. Un schéma JSON pour l’autocomplétion dans l’éditeur se trouve dans [`schema/makedmg.schema.json`](../../schema/makedmg.schema.json).

| Clé | Obligatoire | Par défaut | Remarques |
|---|---|---|---|
| `volumeName` | oui | | Titre de la fenêtre et nom du volume ; pas de `:` |
| `output` | oui | | Remplaçable avec `build -o` |
| `format` | | `ULFO` | `UDZO`, `UDBZ`, `ULFO` (10.11+), `ULMO` (10.15+) |
| `filesystem` | | `HFS+` | `APFS` ne fonctionne pour l’instant qu’avec des arrière-plans de couleur |
| `window` | | 200, 120, 640×400 | Plus `showToolbar`, `showSidebar`, `showStatusBar`, `showPathBar` |
| `icon` | | 128, texte 16, en bas | `labelPosition` : `bottom` ou `right` |
| `background` | | aucun | `{"color": "#RRGGBB"}` ou `{"image": "path"}` |
| `contents` | oui | | Fichiers (`path`, `name` facultatif, `hideExtension`) ou `{"type": "applications"}` |
| `volumeIcon` | | | `.icns` |
| `sign.identity` | | | Signe le DMG avec `codesign --timestamp` |
| `notarize.keychainProfile` | | | Nécessite `sign` ; notarise et agrafe le ticket (staple) |

### Coordonnées et tailles

- `window.x` / `window.y` désignent le coin supérieur gauche de la fenêtre à l’écran. Le Finder stocke une origine en bas à gauche ; makedmg effectue donc la conversion d’après l’écran principal du Mac qui construit l’image.
- `window.width` / `window.height` correspondent au cadre complet de la fenêtre, barre de titre comprise. Sous macOS 26, la barre de titre et la barre d’onglets occupent environ 68 pt : la zone de contenu visible d’une fenêtre de 600×400 fait donc environ 600×332. Tenez-en compte pour dimensionner l’image d’arrière-plan.
- `contents[].x` / `y` sont les centres des icônes, mesurés depuis le coin supérieur gauche de la zone de contenu.
- Le Finder affiche les noms de fichiers en noir sur les arrière-plans personnalisés, en mode clair comme en mode sombre. Des couleurs d’arrière-plan très foncées les rendent difficiles à lire ; `validate` le signale par un avertissement.

### Arrière-plans Retina

Placez `background@2x.png` (exactement deux fois plus grand) à côté de `background.png` : makedmg les fusionne en un TIFF multirésolution avec `tiffutil`. Vous pouvez aussi utiliser une seule image enregistrée à 144 dpi ou plus. Le Finder affiche les arrière-plans en points (pixels × 72 / dpi).

## Signature et notarisation

Enregistrez une seule fois les identifiants de notarisation :

```bash
xcrun notarytool store-credentials notary \
  --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
```

Définissez ensuite `sign.identity` et `notarize.keychainProfile`. `build` signe, soumet, attend, agrafe le ticket et lance une évaluation Gatekeeper. Si Apple rejette la soumission, le journal de notarisation est affiché. Utilisez `--skip-sign` ou `--skip-notarize` pour les builds de test locaux.

## Commandes

| Commande | Rôle |
|---|---|
| `init [--app X.app] [-o file]` | Écrit une configuration de départ |
| `validate -c file [--strict]` | Vérifie les chemins, les plages de valeurs et la disposition ; `--strict` échoue en cas d’avertissement |
| `preview -c file [--appearance light\|dark\|both]` | Rend la fenêtre en PNG sans construire l’image |
| `build -c file [-o out.dmg] [--open]` | Construit, signe et notarise |
| `inspect file.dmg \| .DS_Store` | Affiche les entrées racine et les enregistrements Finder d’un DMG |

Ajoutez `-v` / `--verbose` pour voir chaque commande exécutée par makedmg.

## Fonctionnement

1. `hdiutil create` crée une image en lecture-écriture dimensionnée d’après le contenu.
2. Elle est montée avec `-nobrowse`, pour que le Finder ne l’affiche jamais.
3. Les éléments sont copiés avec `ditto` (qui préserve signatures et attributs étendus), puis le lien Applications, le dossier masqué `.background` et l’icône du volume sont ajoutés.
4. `.DS_Store` est écrit directement : réglages de la fenêtre, options de la présentation par icônes, alias et signet (bookmark) de l’arrière-plan, positions des icônes.
5. L’image est démontée, convertie au format compressé, puis signée, notarisée et agrafée.

## Limitations

- Les arrière-plans image nécessitent une image HFS+ (le format d’alias APFS n’est pas encore vérifié).
- Environ 30 éléments tiennent dans l’unique nœud `.DS_Store` écrit par makedmg.
- La position verticale de la fenêtre dépend de la hauteur d’écran du Mac qui construit l’image.
- Les apps situées sous `/System` ne peuvent pas être copiées (indicateurs de fichier protégés) ; empaquetez votre propre app.

## Licence

MakeDmg est distribué sous la [GNU Affero General Public License v3.0](../../LICENSE).
