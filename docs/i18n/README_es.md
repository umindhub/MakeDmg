# MakeDmg

[English](../../README.md) | [Deutsch](README_de.md) | **Español** | [Français](README_fr.md) | [Italiano](README_it.md) | [日本語](README_ja.md) | [한국어](README_ko.md) | [Nederlands](README_nl.md) | [简体中文](README_zh-Hans.md) | [繁體中文](README_zh-Hant.md)

`makedmg` crea imágenes de disco de macOS con estilo a partir de una configuración JSON: imagen o color de fondo, disposición de iconos, un enlace a Aplicaciones, un icono de volumen, firma de código y notarización.

A diferencia de las herramientas que controlan el Finder mediante AppleScript, makedmg escribe por sí mismo la disposición del Finder (`.DS_Store`). No se abre ninguna ventana del Finder durante la compilación, así que funciona igual en tu Mac y en CI.

## Inicio rápido

```bash
makedmg init --app build/MyApp.app      # writes makedmg.json
makedmg preview -c makedmg.json         # renders preview-light.png / preview-dark.png
makedmg build -c makedmg.json --open    # builds the DMG and opens it
```

## Instalación

Con Homebrew:

```bash
brew install umindhub/tap/makedmg
```

O compílalo desde el código fuente (Swift 6, macOS 13+):

```bash
git clone https://github.com/umindhub/MakeDmg.git && cd MakeDmg
swift build -c release --arch arm64 --arch x86_64
cp .build/apple/Products/Release/makedmg /usr/local/bin/
```

## Configuración

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

Las rutas relativas se resuelven respecto a la carpeta del archivo de configuración. En [`schema/makedmg.schema.json`](../../schema/makedmg.schema.json) hay un JSON Schema para el autocompletado en el editor.

| Clave | Obligatorio | Predeterminado | Notas |
|---|---|---|---|
| `volumeName` | sí | | Título de la ventana y nombre del volumen; sin `:` |
| `output` | sí | | Se puede sobrescribir con `build -o` |
| `format` | | `ULFO` | `UDZO`, `UDBZ`, `ULFO` (10.11+), `ULMO` (10.15+) |
| `filesystem` | | `HFS+` | Por ahora, `APFS` solo funciona con fondos de color |
| `window` | | 200, 120, 640×400 | Además `showToolbar`, `showSidebar`, `showStatusBar`, `showPathBar` |
| `icon` | | 128, texto 16, abajo | `labelPosition`: `bottom` o `right` |
| `background` | | ninguno | `{"color": "#RRGGBB"}` o `{"image": "path"}` |
| `contents` | sí | | Archivos (`path`, `name` opcional, `hideExtension`) o `{"type": "applications"}` |
| `volumeIcon` | | | `.icns` |
| `sign.identity` | | | Firma el DMG con `codesign --timestamp` |
| `notarize.keychainProfile` | | | Requiere `sign`; notariza y grapa el ticket (staple) |

### Coordenadas y tamaños

- `window.x` / `window.y` son la esquina superior izquierda de la ventana en la pantalla. El Finder guarda un origen en la esquina inferior izquierda, por lo que makedmg convierte usando la pantalla principal del Mac que compila.
- `window.width` / `window.height` son el marco completo de la ventana, barra de título incluida. En macOS 26 la barra de título y la barra de pestañas ocupan unos 68 pt, así que el área de contenido visible de una ventana de 600×400 es de unos 600×332. Tenlo en cuenta al dimensionar la imagen de fondo.
- `contents[].x` / `y` son los centros de los iconos, medidos desde la esquina superior izquierda del área de contenido.
- El Finder dibuja los nombres de archivo en negro sobre fondos personalizados, tanto en modo claro como en modo oscuro. Los colores de fondo muy oscuros los hacen difíciles de leer; `validate` avisa de ello.

### Fondos Retina

Coloca `background@2x.png` (exactamente el doble de tamaño) junto a `background.png`, y makedmg los combinará en un TIFF multirresolución con `tiffutil`, o usa una sola imagen guardada a 144 ppp o más. El Finder dibuja los fondos en tamaño de puntos (píxeles × 72 / ppp).

## Firma y notarización

Guarda las credenciales de notarización una sola vez:

```bash
xcrun notarytool store-credentials notary \
  --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
```

Después define `sign.identity` y `notarize.keychainProfile`. `build` firma, envía, espera, grapa el ticket y ejecuta una evaluación de Gatekeeper. Si Apple rechaza el envío, se imprime el registro de notarización. Usa `--skip-sign` o `--skip-notarize` para compilaciones de prueba locales.

## Comandos

| Comando | Propósito |
|---|---|
| `init [--app X.app] [-o file]` | Escribe una configuración inicial |
| `validate -c file [--strict]` | Comprueba rutas, rangos y disposición; `--strict` falla si hay advertencias |
| `preview -c file [--appearance light\|dark\|both]` | Renderiza la ventana a PNG sin compilar |
| `build -c file [-o out.dmg] [--open]` | Compila, firma y notariza |
| `inspect file.dmg \| .DS_Store` | Muestra las entradas raíz y los registros del Finder de un DMG |

Añade `-v` / `--verbose` para ver cada comando que ejecuta makedmg.

## Cómo funciona

1. Crea con `hdiutil create` una imagen de lectura y escritura dimensionada según el contenido.
2. La monta con `-nobrowse`, para que el Finder nunca la muestre.
3. Copia los elementos con `ditto` (conserva firmas y atributos extendidos) y añade el enlace a Aplicaciones, la carpeta oculta `.background` y el icono del volumen.
4. Escribe `.DS_Store` directamente: ajustes de la ventana, opciones de la vista de iconos, el alias y el bookmark del fondo, y las posiciones de los iconos.
5. Desmonta, convierte al formato comprimido y luego firma, notariza y grapa el ticket.

## Limitaciones

- Los fondos con imagen necesitan una imagen HFS+ (el formato de alias de APFS aún no está verificado).
- Caben unos 30 elementos en el único nodo de `.DS_Store` que escribe makedmg.
- La posición vertical de la ventana depende de la altura de pantalla del Mac que compila.
- Las apps de `/System` no se pueden copiar (flags de archivo protegidos); empaqueta tu propia app.

## Licencia

MakeDmg se distribuye bajo la [GNU Affero General Public License v3.0](../../LICENSE).
