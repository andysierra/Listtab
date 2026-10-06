#!/bin/bash
# Construye dist/listtab_<versión>_all.deb (Python puro: arquitectura "all").
#   /usr/bin/listtab                                   lanzador
#   /usr/lib/listtab/{listtab,resources}/              programa
#   /usr/share/applications/listtab.desktop            menú de aplicaciones / rofi
#   /usr/share/icons/hicolor/scalable/apps/listtab.svg ícono
#   /usr/share/doc/listtab/                            README, LEEME, copyright
# Uso: packaging/build-deb.sh
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION=$(python3 -c "import re; print(re.search(r'__version__ = \"(.+)\"', open('listtab/__init__.py').read())[1])")
PKG=listtab
OUT=dist/${PKG}_${VERSION}_all.deb
ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT

install -d "$ROOT/DEBIAN" "$ROOT/usr/bin" "$ROOT/usr/lib/$PKG" "$ROOT/usr/share/applications" \
           "$ROOT/usr/share/icons/hicolor/scalable/apps" "$ROOT/usr/share/doc/$PKG"
cp -r listtab resources "$ROOT/usr/lib/$PKG/"
find "$ROOT/usr/lib/$PKG" -name __pycache__ -type d -prune -exec rm -rf {} +

cat > "$ROOT/usr/bin/listtab" <<'SH'
#!/bin/sh
exec env PYTHONPATH=/usr/lib/listtab${PYTHONPATH:+:$PYTHONPATH} python3 -m listtab "$@"
SH
chmod 755 "$ROOT/usr/bin/listtab"

install -m644 resources/listtab.svg "$ROOT/usr/share/icons/hicolor/scalable/apps/listtab.svg"
cat > "$ROOT/usr/share/applications/listtab.desktop" <<'DESK'
[Desktop Entry]
Type=Application
Name=ListTab
GenericName=Window Switcher
Comment=Alt+Tab con una lista de ventanas y sus títulos completos
Exec=listtab
Icon=listtab
Terminal=false
Categories=Utility;
Keywords=alt-tab;alttab;switcher;windows;ventanas;
StartupNotify=false
DESK
install -m644 README.md "$ROOT/usr/share/doc/$PKG/README.md"
install -m644 resources/LEEME.txt "$ROOT/usr/share/doc/$PKG/LEEME.txt"
{ echo "Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/"
  echo "Upstream-Name: ListTab"
  echo "Source: https://github.com/andysierra/Listtab"
  echo
  echo "Files: *"
  echo "License: MIT"
  sed 's/^$/./; s/^/ /' LICENSE; } > "$ROOT/usr/share/doc/$PKG/copyright"

cat > "$ROOT/DEBIAN/control" <<CTRL
Package: $PKG
Version: $VERSION
Architecture: all
Maintainer: andysierra <camilo-hormiga@hotmail.com>
Homepage: https://github.com/andysierra/Listtab
Section: x11
Priority: optional
Installed-Size: $(du -sk "$ROOT/usr" | cut -f1)
Depends: python3 (>= 3.10), python3-gi, python3-gi-cairo, python3-cairo, python3-xlib, gir1.2-gtk-3.0, gir1.2-wnck-3.0
Recommends: gir1.2-ayatanaappindicator3-0.1
Description: Alt+Tab with a list of windows and their full titles (MATE / X11)
 Window switcher for the MATE desktop on X11: Alt+Tab shows every window as a
 row (icon, full title, app), most recent first, tracked per window. Close
 windows from the list, click a row to jump, all workspaces or just the
 current one. Port of ListTab for macOS.
 .
 It takes over Alt+Tab from Marco while running and gives it back on quit
 (listtab --restore-native if it was force-killed).
CTRL

# Menú e íconos al día tras instalar/desinstalar
for s in postinst postrm; do
cat > "$ROOT/DEBIAN/$s" <<'HOOK'
#!/bin/sh
set -e
command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q -t /usr/share/icons/hicolor || true
command -v update-desktop-database >/dev/null && update-desktop-database -q /usr/share/applications || true
exit 0
HOOK
chmod 755 "$ROOT/DEBIAN/$s"
done

chmod -R u+rwX,go+rX,go-w "$ROOT"   # 644 / 755 aunque el umask del repo sea 002
mkdir -p dist
fakeroot dpkg-deb --build --root-owner-group "$ROOT" "$OUT" >/dev/null
echo "$OUT"
