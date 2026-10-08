#!/bin/zsh
# Compila ListTab y arma ListTab.app (agente sin icono en el Dock).
# Uso: ./build.sh            -> build/ListTab.app
#      ./build.sh install    -> ademas copia a ~/Applications
set -e
cd "${0:A:h}"
swift build -c release --arch arm64 --arch x86_64   # binario universal (Apple Silicon + Intel)
BIN=.build/apple/Products/Release/ListTab
APP=build/ListTab.app
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/ListTab"
cp resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cat > "$APP/Contents/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.andysierra.listtab</string>
  <key>CFBundleName</key><string>ListTab</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleExecutable</key><string>ListTab</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PL
# Firma con el certificado local si existe (el permiso de Accesibilidad sobrevive a recompilar);
# si no, ad-hoc (hay que re-conceder el permiso en cada build). Ver README, "Firma estable".
SIGN="ListTab Local Signing"
if security find-identity -p codesigning | grep -q "$SIGN"; then
  codesign --force --sign "$SIGN" --identifier com.andysierra.listtab "$APP"
else
  echo "AVISO: sin certificado '$SIGN'; firma ad-hoc"
  codesign --force --sign - --identifier com.andysierra.listtab "$APP"
fi
echo "OK -> $APP"
if [[ "$1" == install ]]; then
  mkdir -p ~/Applications && rm -rf ~/Applications/ListTab.app && cp -R "$APP" ~/Applications/
  echo "Instalada en ~/Applications/ListTab.app"
fi
