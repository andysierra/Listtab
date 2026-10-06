#!/bin/zsh
# Regenera las capturas del README (images/*.png) con el modo --demo: ventanas ficticias sobre un fondo
# propio, asi no sale nada del escritorio real. Requiere haber compilado (./build.sh) y que la
# terminal tenga permiso de Grabacion de pantalla.
# Uso: tools/screenshots.sh
cd "${0:A:h}/.."
BIN=build/ListTab.app/Contents/MacOS/ListTab
mkdir -p images

shot() {   # shot <nombre> <count> <select> <margen>
  local name=$1 count=$2 sel=$3 m=$4 out=$(mktemp)
  $BIN --show --demo --count=$count --select=$sel --hold=5 > "$out" &
  local pid=$!
  for i in {1..40}; do grep -q FRAME "$out" && break; sleep 0.25; done
  read -r _ x y w h < <(grep FRAME "$out")
  sleep 0.6
  screencapture -x -R"$((x-m)),$((y-m)),$((w+2*m)),$((h+2*m))" "images/$name.png"
  wait $pid 2>/dev/null; rm -f "$out"
  echo "images/$name.png"
}

shot panel      7  1 70
shot panel-many 23 1 50
cp build/AppIcon.iconset/icon_512x512.png images/icon.png 2>/dev/null || true
