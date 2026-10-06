#!/bin/zsh
# Genera dist/ListTab-<version>.dmg (universal) para compartir.
# OJO: `hdiutil create -srcfolder` falla aqui con "Recurso ocupado"; por eso se crea una imagen
# con tamano fijo, se monta, se copia y se convierte (create -size + attach funcionan).
set -e
cd "${0:A:h}"
VERSION=$(grep -A1 CFBundleShortVersionString build.sh | grep -o '<string>[^<]*' | head -1 | sed 's/<string>//')
./build.sh
mkdir -p dist build
RW=build/ListTab-rw.dmg; DMG="dist/ListTab-$VERSION.dmg"; MNT=/Volumes/ListTabBuild
rm -f "$RW" "$DMG"
hdiutil detach "$MNT" >/dev/null 2>&1 || true
SIZE=$(( $(du -sm build/ListTab.app | cut -f1) + 20 ))
hdiutil create -size ${SIZE}m -fs HFS+ -volname ListTab -ov "$RW" >/dev/null
hdiutil attach "$RW" -nobrowse -mountpoint "$MNT" >/dev/null
cp -R build/ListTab.app "$MNT/"
ln -s /Applications "$MNT/Applications"
cp resources/LEEME.txt "$MNT/LEEME.txt"
sync; hdiutil detach "$MNT" >/dev/null
hdiutil convert "$RW" -format UDZO -o "$DMG" >/dev/null
rm -f "$RW"
echo "OK -> $DMG ($(du -h "$DMG" | cut -f1))  arquitecturas: $(lipo -archs build/ListTab.app/Contents/MacOS/ListTab)"
