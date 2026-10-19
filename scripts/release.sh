#!/usr/bin/env bash
# Builds a universal makedmg, signs + notarizes it, and publishes a GitHub release.
# The release triggers .github/workflows/homebrew.yml, which bumps the tap formula.
# Usage: scripts/release.sh 0.1.0
set -euo pipefail

VERSION="${1:-}"
SIGN_ID="${SIGN_ID:-Developer ID Application: ShaoXin Cai (63MSW5QTJL)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-apppad-notary}"   # xcrun notarytool store-credentials
BUNDLE_ID="com.youmindhub.makedmg"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok()   { printf '\033[32m✓ %s\033[0m\n' "$*"; }
fail() { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

[[ "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Usage: scripts/release.sh <major.minor.patch>"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
TAG="v${VERSION}"
DIST="${ROOT}/dist"
ARCHIVE="${DIST}/makedmg-${VERSION}-macos.tar.gz"
APPINFO="Sources/MakeDmgKit/AppInfo.swift"

# ─── Preconditions ────────────────────────────────────────
step "Checking repository"
command -v gh >/dev/null || fail "GitHub CLI (gh) not found: brew install gh"
git diff --quiet && git diff --cached --quiet || fail "Commit or stash your changes first"
if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then fail "Tag ${TAG} already exists"; fi
xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" >/dev/null 2>&1 \
  || fail "Notary profile '${NOTARY_PROFILE}' missing: xcrun notarytool store-credentials ${NOTARY_PROFILE} --apple-id <id> --team-id <team>"
ok "Clean tree, ${TAG} is free"

# ─── Version bump ─────────────────────────────────────────
step "Setting version ${VERSION}"
# Use the system BSD sed/tar explicitly; GNU versions in PATH take different flags.
/usr/bin/sed -i '' -E "s/(public static let version = \")[^\"]*\"/\1${VERSION}\"/" "${APPINFO}"
grep -q "version = \"${VERSION}\"" "${APPINFO}" || fail "Could not update ${APPINFO}"
if ! git diff --quiet; then
  git commit -qam "Release ${VERSION}"
  ok "Committed version bump"
fi

# ─── Test and build ───────────────────────────────────────
step "Testing"
swift test

step "Building universal binary"
swift build -c release --arch arm64 --arch x86_64
BIN="${ROOT}/.build/apple/Products/Release/makedmg"
ARCHS="$(lipo -archs "${BIN}")"
[[ "${ARCHS}" == *arm64* && "${ARCHS}" == *x86_64* ]] || fail "Not universal: ${ARCHS}"
ok "Architectures: ${ARCHS}"

rm -rf "${DIST}"
mkdir -p "${DIST}/stage"
cp "${BIN}" "${DIST}/stage/makedmg"
cp LICENSE README.md "${DIST}/stage/"

# ─── Sign ─────────────────────────────────────────────────
step "Signing"
codesign --force --options runtime --timestamp --identifier "${BUNDLE_ID}" \
  --sign "${SIGN_ID}" "${DIST}/stage/makedmg"
codesign --verify --strict --verbose=2 "${DIST}/stage/makedmg"
[[ "$("${DIST}/stage/makedmg" --version)" == "${VERSION}" ]] || fail "Binary reports a different version"
ok "Signed with ${SIGN_ID}"

# ─── Notarize (bare binaries cannot be stapled; Gatekeeper checks online) ──
step "Notarizing"
ditto -c -k "${DIST}/stage/makedmg" "${DIST}/makedmg-notarize.zip"
xcrun notarytool submit "${DIST}/makedmg-notarize.zip" \
  --keychain-profile "${NOTARY_PROFILE}" --wait --output-format json > "${DIST}/notary.json" || true
STATUS="$(plutil -extract status raw -o - "${DIST}/notary.json" 2>/dev/null || echo unknown)"
if [[ "${STATUS}" != "Accepted" ]]; then
  cat "${DIST}/notary.json"
  SUBMISSION="$(plutil -extract id raw -o - "${DIST}/notary.json" 2>/dev/null || true)"
  [[ -n "${SUBMISSION}" ]] && xcrun notarytool log "${SUBMISSION}" --keychain-profile "${NOTARY_PROFILE}" || true
  fail "Notarization status: ${STATUS}"
fi
rm -f "${DIST}/makedmg-notarize.zip"
ok "Notarized"

# ─── Package ──────────────────────────────────────────────
step "Packaging"
COPYFILE_DISABLE=1 /usr/bin/tar --no-xattrs -czf "${ARCHIVE}" -C "${DIST}/stage" makedmg LICENSE README.md
(cd "${DIST}" && shasum -a 256 "$(basename "${ARCHIVE}")" > "$(basename "${ARCHIVE}").sha256")
ok "$(cat "${ARCHIVE}.sha256")"

# ─── Publish ──────────────────────────────────────────────
step "Publishing ${TAG}"
git push origin HEAD
git tag -a "${TAG}" -m "makedmg ${VERSION}"
git push origin "${TAG}"
gh release create "${TAG}" "${ARCHIVE}" "${ARCHIVE}.sha256" \
  --title "makedmg ${VERSION}" --generate-notes
ok "Released ${TAG}; the Homebrew workflow will bump the tap"
