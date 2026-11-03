#!/bin/zsh
set -e
cd "$(dirname "$0")"
APP="build/Modo PC.app"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
SDK=$(xcrun --sdk macosx --show-sdk-path)
for arch in x86_64 arm64; do
  swiftc -O -sdk "$SDK" -target ${arch}-apple-macos12.0 -o "build/modopc-$arch" Sources/*.swift
done
lipo -create build/modopc-x86_64 build/modopc-arm64 -output "$APP/Contents/MacOS/ModoPC"
cp Info.plist "$APP/Contents/"
cp icone.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --deep -s - -r='designated => identifier "com.modopc.app"' "$APP"
echo "Gerado: $APP"
