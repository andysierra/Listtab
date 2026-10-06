"""Modo demo (`--show --demo`): ventanas ficticias sobre un fondo propio, para capturas del README
sin mostrar el escritorio real. Uso: listtab --show --demo [--count=7] [--select=1] [--hold=6]
"""
import sys

import cairo
from gi.repository import Gdk, Gtk

from listtab.windows import SwitchWindow, themed_icon


def enabled():
    return "--demo" in sys.argv


def int_arg(name, default):
    for a in sys.argv:
        if a.startswith(f"--{name}="):
            try:
                return int(a.split("=", 1)[1])
            except ValueError:
                pass
    return default


# (íconos candidatos del tema, app, título): equivalentes Linux de la lista de la versión macOS
POOL = [
    (["org.wezfurlong.wezterm", "utilities-terminal"], "WezTerm", "yazi: Escritorio"),
    (["org.wezfurlong.wezterm", "utilities-terminal"], "WezTerm", "yazi: dev"),
    (["zed", "dev.zed.Zed", "text-editor"], "Zed", "ListTab — keyboard.py"),
    (["brave-browser", "web-browser"], "Brave", "Hacker News"),
    (["thunderbird", "mail-client", "internet-mail"], "Thunderbird", "Bandeja de entrada — 3 sin leer"),
    (["sublime-text", "accessories-text-editor"], "Sublime Text", "Ideas para el finde"),
    (["system-file-manager", "caja"], "Caja", "Descargas"),
    (["office-calendar", "x-office-calendar"], "Calendario", "Octubre 2026"),
    (["utilities-terminal", "mate-terminal"], "Terminal", "bash — 120×32"),
    (["org.x.viewer", "xviewer", "image-viewer"], "Visor de imágenes", "architecture-diagram.png"),
    (["com.visualstudio.code", "vscode", "code"], "Visual Studio Code", "index.html — 03-gifs-app"),
    (["rhythmbox", "multimedia-audio-player"], "Rhythmbox", "Biblioteca"),
    (["preferences-desktop", "mate-control-center"], "Centro de control", "Teclado"),
    (["accessories-text-editor", "org.x.editor"], "Editor de textos", "todo.txt"),
    (["application-x-tml24free", "x-office-document"], "Word (FreeOffice TextMaker)", "Informe.docx"),
    (["application-x-pml24free", "x-office-spreadsheet"], "Excel (FreeOffice PlanMaker)", "Presupuesto.xlsx"),
    (["utilities-system-monitor", "mate-system-monitor"], "Monitor del sistema", "Procesos"),
    (["org.wezfurlong.wezterm", "utilities-terminal"], "WezTerm", "vim: README.md"),
    (["brave-browser", "web-browser"], "Brave", "Documentación de GTK"),
    (["zed", "text-editor"], "Zed", "panel.py"),
    (["accessories-calculator", "mate-calc"], "Calculadora", "Calculadora"),
    (["sublime-text", "accessories-text-editor"], "Sublime Text", "Mercado"),
    (["audio-input-microphone", "multimedia-audio-player"], "Grabadora", "Nueva grabación"),
]


def _icon(names):
    for n in names:
        pix = themed_icon(n)
        if pix is not None:
            return pix
    return themed_icon("application-x-executable")


def windows(count):
    out = []
    for i in range(count):
        names, app, title = POOL[i % len(POOL)]
        out.append(SwitchWindow(pid=0, xid=i + 1, app_name=app, title=title, icon=_icon(names)))
    return out


def make_backdrop():
    """Ventana a pantalla completa con un degradado (colores tokyo-night), debajo del panel."""
    win = Gtk.Window(type=Gtk.WindowType.POPUP)
    geo = Gdk.Display.get_default().get_primary_monitor().get_geometry()
    win.move(geo.x, geo.y)
    win.resize(geo.width, geo.height)
    win.set_app_paintable(True)

    def draw(_w, cr):
        w, h = geo.width, geo.height

        def c(r, g, b, a=1.0):
            return r / 255, g / 255, b / 255, a

        lin = cairo.LinearGradient(0, h, w, 0)
        lin.add_color_stop_rgba(0, *c(26, 27, 38))
        lin.add_color_stop_rgba(1, *c(36, 40, 59))
        cr.set_source(lin)
        cr.paint()
        for (fx, fy, rad, col) in ((0.18, 0.15, 0.55, (122, 162, 247, 0.55)),
                                   (0.85, 0.90, 0.50, (187, 154, 247, 0.45))):
            g = cairo.RadialGradient(w * fx, h * fy, 0, w * fx, h * fy, w * rad)
            g.add_color_stop_rgba(0, *c(*col))
            g.add_color_stop_rgba(1, *c(*col[:3], 0))
            cr.set_source(g)
            cr.paint()
        return True

    win.connect("draw", draw)
    return win
