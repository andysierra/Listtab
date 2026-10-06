#!/bin/bash
# Regenera las capturas del README (images/*.png) con el modo --demo: ventanas ficticias sobre un fondo
# propio, así no sale nada del escritorio real. La captura se hace con GDK (sin herramientas extra).
# Uso: tools/screenshots.sh
set -e
cd "$(dirname "$0")/.."
mkdir -p images

shot() {   # shot <nombre> <count> <select> <margen>
  local name=$1 count=$2 sel=$3 m=$4 out
  out=$(mktemp)
  python3 -m listtab --show --demo --count="$count" --select="$sel" --hold=4 > "$out" &
  local pid=$!
  for _ in $(seq 1 40); do grep -q FRAME "$out" && break; sleep 0.25; done
  read -r _ x y w h < <(grep FRAME "$out")
  sleep 0.6
  python3 - "$x" "$y" "$w" "$h" "$m" "images/$name.png" <<'PY'
import sys, gi
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk
x, y, w, h, m = (int(v) for v in sys.argv[1:6])
root = Gdk.get_default_root_window()
Gdk.pixbuf_get_from_window(root, x - m, y - m, w + 2 * m, h + 2 * m).savev(sys.argv[6], "png", [], [])
PY
  wait $pid 2>/dev/null || true
  rm -f "$out"
  echo "images/$name.png"
}

shot panel      7  1 70
shot panel-many 23 1 50
python3 -c "
import gi; gi.require_version('GdkPixbuf', '2.0'); from gi.repository import GdkPixbuf
GdkPixbuf.Pixbuf.new_from_file_at_size('resources/listtab.svg', 512, 512).savev('images/icon.png', 'png', [], [])"
echo images/icon.png
