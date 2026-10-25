#!/usr/bin/env bash
# Compila Keytone y genera dist/Keytone.app, dist/Keytone.zip y dist/Keytone.dmg.
#
# Variables opcionales:
#   VERSION=1.2.0        versión visible
#   ARCHS="arm64"        arquitecturas (por defecto, universal: arm64 + x86_64; requiere Xcode)
#   SIGN_IDENTITY="..."  identidad de firma (por defecto, firma ad-hoc "-")
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-1.0.0}"
BUILD="${BUILD:-$(date +%Y%m%d%H%M)}"
ARCHS="${ARCHS:-arm64 x86_64}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

ARCH_FLAGS=()
for arch in $ARCHS; do ARCH_FLAGS+=(--arch "$arch"); done

echo "▸ Compilando ($ARCHS)…"
swift build -c release "${ARCH_FLAGS[@]}"
BIN_DIR="$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)"

APP="dist/Keytone.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Keytone" "$APP/Contents/MacOS/Keytone"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Resources/Info.plist > "$APP/Contents/Info.plist"

echo "▸ Generando icono…"
ICONSET="dist/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET"

echo "▸ Firmando ($SIGN_IDENTITY)…"
codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$APP"

echo "▸ Empaquetando…"
ditto -c -k --keepParent "$APP" dist/Keytone.zip
STAGE="dist/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Keytone" -srcfolder "$STAGE" -ov -format UDZO dist/Keytone.dmg >/dev/null
rm -rf "$STAGE"

echo "✓ Listo: dist/Keytone.app, dist/Keytone.zip, dist/Keytone.dmg"
