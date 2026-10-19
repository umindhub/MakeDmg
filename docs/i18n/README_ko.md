# MakeDmg

[English](../../README.md) | [Deutsch](README_de.md) | [Español](README_es.md) | [Français](README_fr.md) | [Italiano](README_it.md) | [日本語](README_ja.md) | **한국어** | [Nederlands](README_nl.md) | [简体中文](README_zh-Hans.md) | [繁體中文](README_zh-Hant.md)

`makedmg`는 JSON 설정으로 스타일이 적용된 macOS 디스크 이미지를 만듭니다. 배경 이미지 또는 배경색, 아이콘 배치, Applications 링크, 볼륨 아이콘, 코드 서명과 공증을 지원합니다.

AppleScript로 Finder를 조작하는 도구와 달리, makedmg는 Finder 레이아웃(`.DS_Store`)을 직접 작성합니다. 빌드 중에 Finder 창이 열리지 않으므로 내 Mac에서도 CI에서도 똑같이 동작합니다.

## 빠른 시작

```bash
makedmg init --app build/MyApp.app      # writes makedmg.json
makedmg preview -c makedmg.json         # renders preview-light.png / preview-dark.png
makedmg build -c makedmg.json --open    # builds the DMG and opens it
```

## 설치

Homebrew 사용:

```bash
brew install umindhub/tap/makedmg
```

또는 소스에서 빌드(Swift 6, macOS 13 이상):

```bash
git clone https://github.com/umindhub/MakeDmg.git && cd MakeDmg
swift build -c release --arch arm64 --arch x86_64
cp .build/apple/Products/Release/makedmg /usr/local/bin/
```

## 설정

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

상대 경로는 설정 파일이 있는 폴더를 기준으로 해석됩니다. 편집기 자동 완성을 위한 JSON Schema는 [`schema/makedmg.schema.json`](../../schema/makedmg.schema.json)에 있습니다.

| 키 | 필수 | 기본값 | 비고 |
|---|---|---|---|
| `volumeName` | 예 | | 창 제목이자 볼륨 이름; `:` 사용 불가 |
| `output` | 예 | | `build -o`로 덮어쓸 수 있음 |
| `format` | | `ULFO` | `UDZO`, `UDBZ`, `ULFO` (10.11+), `ULMO` (10.15+) |
| `filesystem` | | `HFS+` | 현재 `APFS`는 단색 배경에서만 동작 |
| `window` | | 200, 120, 640×400 | 그 외 `showToolbar`, `showSidebar`, `showStatusBar`, `showPathBar` |
| `icon` | | 128, 텍스트 16, 아래 | `labelPosition`: `bottom` 또는 `right` |
| `background` | | 없음 | `{"color": "#RRGGBB"}` 또는 `{"image": "path"}` |
| `contents` | 예 | | 파일(`path`, 선택 사항 `name`, `hideExtension`) 또는 `{"type": "applications"}` |
| `volumeIcon` | | | `.icns` |
| `sign.identity` | | | `codesign --timestamp`로 DMG에 서명 |
| `notarize.keychainProfile` | | | `sign` 필요; 공증 후 티켓을 스테이플 |

### 좌표와 크기

- `window.x` / `window.y`는 화면에서 창의 왼쪽 위 모서리입니다. Finder는 왼쪽 아래를 원점으로 저장하므로, makedmg는 빌드하는 Mac의 주 디스플레이를 기준으로 변환합니다.
- `window.width` / `window.height`는 제목 표시줄을 포함한 창 전체 프레임입니다. macOS 26에서는 제목 표시줄과 탭 막대가 약 68pt를 차지하므로, 600×400 창의 실제 보이는 콘텐츠 영역은 약 600×332입니다. 배경 이미지 크기를 정할 때 이 점을 고려하세요.
- `contents[].x` / `y`는 아이콘 중심 좌표이며, 콘텐츠 영역의 왼쪽 위에서부터 측정합니다.
- 사용자 지정 배경에서 Finder는 라이트 모드와 다크 모드 모두 파일 이름을 검은색으로 그립니다. 배경색이 매우 어두우면 읽기 어려우므로 `validate`가 경고합니다.

### Retina 배경

`background.png` 옆에 `background@2x.png`(정확히 2배 크기)를 두면 makedmg가 `tiffutil`로 다중 해상도 TIFF로 합칩니다. 또는 144dpi 이상으로 저장한 이미지 한 장을 사용할 수도 있습니다. Finder는 배경을 포인트 크기(픽셀 × 72 / dpi)로 그립니다.

## 서명과 공증

공증 자격 증명을 한 번만 저장합니다:

```bash
xcrun notarytool store-credentials notary \
  --apple-id you@example.com --team-id TEAMID --password <app-specific-password>
```

그다음 `sign.identity`와 `notarize.keychainProfile`을 설정합니다. `build`는 서명, 제출, 대기, 스테이플을 수행하고 Gatekeeper 평가를 실행합니다. Apple이 제출을 거부하면 공증 로그가 출력됩니다. 로컬 테스트 빌드에는 `--skip-sign` 또는 `--skip-notarize`를 사용하세요.

## 명령어

| 명령어 | 용도 |
|---|---|
| `init [--app X.app] [-o file]` | 시작용 설정 파일 작성 |
| `validate -c file [--strict]` | 경로, 값 범위, 레이아웃 검사; `--strict`는 경고에도 실패 |
| `preview -c file [--appearance light\|dark\|both]` | 빌드 없이 창을 PNG로 렌더링 |
| `build -c file [-o out.dmg] [--open]` | 빌드, 서명, 공증 |
| `inspect file.dmg \| .DS_Store` | DMG의 루트 항목과 Finder 레코드 표시 |

`-v` / `--verbose`를 추가하면 makedmg가 실행하는 모든 명령을 볼 수 있습니다.

## 동작 방식

1. `hdiutil create`로 내용물 크기에 맞춘 읽기/쓰기 이미지를 만듭니다.
2. `-nobrowse`로 마운트하므로 Finder에 표시되지 않습니다.
3. `ditto`로 항목을 복사하고(서명과 확장 속성 보존), Applications 링크, 숨김 폴더 `.background`, 볼륨 아이콘을 추가합니다.
4. `.DS_Store`를 직접 작성합니다: 창 설정, 아이콘 보기 옵션, 배경의 별칭(alias)과 북마크, 아이콘 위치.
5. 분리(detach)한 뒤 압축 형식으로 변환하고, 서명, 공증, 스테이플을 수행합니다.

## 제한 사항

- 이미지 배경에는 HFS+ 이미지가 필요합니다(APFS 별칭 형식은 아직 검증되지 않았습니다).
- makedmg가 작성하는 단일 `.DS_Store` 노드에는 약 30개 항목이 들어갑니다.
- 창의 세로 위치는 빌드하는 Mac의 화면 높이에 따라 달라집니다.
- `/System` 아래의 앱은 복사할 수 없습니다(보호된 파일 플래그). 직접 만든 앱을 패키징하세요.

## 라이선스

MakeDmg는 [GNU Affero General Public License v3.0](../../LICENSE)에 따라 배포됩니다.
