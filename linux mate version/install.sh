#!/bin/bash
# Instala ListTab para el usuario actual (sin sudo):
#   ~/.local/share/listtab/       copia del programa (listtab/, resources/, bin/)
#   ~/.local/bin/listtab          enlace al lanzador
#   ~/.local/share/applications/listtab.desktop + ícono en el tema hicolor ("listtab" en rofi/menú)
# Uso: ./install.sh            instala / actualiza
#      ./install.sh uninstall  desinstala (restaura antes el Alt+Tab nativo)
set -euo pipefail
cd "$(dirname "$0")"
DEST="$HOME/.local/share/listtab"
APPS="$HOME/.local/share/applications"
ICONS="$HOME/.local/share/icons/hicolor/scalable/apps"

if [[ "${1:-}" == uninstall ]]; then
    pkill -TERM -f 'python3 -m listtab$' 2>/dev/null || true
    sleep 0.5
    "$DEST/bin/listtab" --login-off >/dev/null 2>&1 || true
    "$DEST/bin/listtab" --restore-native 2>/dev/null || true
    rm -rf "$DEST" "$HOME/.local/bin/listtab" "$APPS/listtab.desktop" "$ICONS/listtab.svg"
    echo "ListTab desinstalado"
    exit 0
fi

# dependencias (todas vienen con Linux Mint MATE)
python3 - <<'PY'
import gi
for ns, v in [("Gtk", "3.0"), ("Wnck", "3.0"), ("GdkX11", "3.0")]:
    gi.require_version(ns, v)
import Xlib  # python3-xlib
PY

rm -rf "$DEST" && mkdir -p "$DEST" "$HOME/.local/bin" "$APPS" "$ICONS"
cp -r listtab resources bin "$DEST/"
find "$DEST" -name __pycache__ -type d -prune -exec rm -rf {} +
ln -sf "$DEST/bin/listtab" "$HOME/.local/bin/listtab"
cp resources/listtab.svg "$ICONS/listtab.svg"
rm -f "$HOME/.local/share/icons/hicolor/icon-theme.cache"
cat > "$APPS/listtab.desktop" <<DESK
[Desktop Entry]
Type=Application
Name=ListTab
Comment=Alt+Tab con una lista de ventanas y sus títulos completos
Exec=$DEST/bin/listtab
Icon=listtab
Categories=Utility;
Keywords=alt-tab;switcher;windows;ventanas;
DESK
# si estaba activado "Abrir al iniciar sesión", reescribirlo con la ruta instalada
[[ -f "$HOME/.config/autostart/listtab.desktop" ]] && "$DEST/bin/listtab" --login-on >/dev/null
echo "Instalado en $DEST  (ejecutar: listtab, o 'ListTab' en el menú / rofi)"
