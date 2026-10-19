#!/bin/sh
# Builds a minimal, ad-hoc signed Demo.app for trying makedmg without your own app.
set -eu
cd "$(dirname "$0")"

APP=build/Demo.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Demo</string>
    <key>CFBundleIdentifier</key><string>com.example.makedmg.demo</string>
    <key>CFBundleName</key><string>Demo</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict>
</plist>
PLIST

printf '#!/bin/sh\nexit 0\n' > "$APP/Contents/MacOS/Demo"
chmod +x "$APP/Contents/MacOS/Demo"

# Plain byte copy: no protected flags or xattrs from the system file.
ICON=/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns
if [ -f "$ICON" ]; then
    cat "$ICON" > "$APP/Contents/Resources/AppIcon.icns"
fi

codesign --force --sign - "$APP" >/dev/null 2>&1 || true
echo "Created $(pwd)/$APP"
