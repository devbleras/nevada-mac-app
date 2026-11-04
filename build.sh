#!/bin/zsh
# Compila Nevada (Apple Silicon + Intel) y la empaqueta en build/Nevada.app y build/Nevada.zip
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/Nevada"

if [[ ! -f Resources/AppIcon.icns ]]; then
    swift Scripts/make-icon.swift Resources/AppIcon.icns
fi

APP=build/Nevada.app
rm -rf "$APP" build/Nevada.zip
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Nevada"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Firma local (ad hoc). Para distribuir sin avisos de Gatekeeper hace falta
# firmar con un Developer ID y notarizar con una cuenta de Apple Developer.
codesign --force --sign - "$APP" >/dev/null

ditto -c -k --keepParent "$APP" build/Nevada.zip
echo "Lista: $APP  (y build/Nevada.zip para compartir)"
