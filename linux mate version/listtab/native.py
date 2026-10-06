"""Apagar / restaurar el Alt+Tab nativo de MATE (equivalente a CGSSetSymbolicHotKeyEnabled en macOS).

Marco (el gestor de ventanas de MATE) es dueño de Alt+Tab: mientras lo tenga, nadie más puede
capturarlo (XGrabKey devuelve BadAccess). Se ponen sus atajos de "cambiar ventana" en 'disabled' y se
guardan los valores originales en ~/.config/listtab/native.json. Ese archivo SOBREVIVE a un cierre
forzado: si ListTab muere y Alt+Tab deja de andar, `listtab --restore-native` lo devuelve.
"""
import json
import os

from gi.repository import Gio

SCHEMA = "org.mate.Marco.global-keybindings"
KEYS = ["switch-windows", "switch-windows-backward", "switch-windows-all", "switch-windows-all-backward"]
STATE = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "listtab", "native.json")


def _settings():
    return Gio.Settings.new(SCHEMA)


def disable():
    s = _settings()
    if not os.path.exists(STATE):   # si ya existe, quedó de un cierre forzado: conservar los originales
        os.makedirs(os.path.dirname(STATE), exist_ok=True)
        with open(STATE, "w") as f:
            json.dump({k: s.get_string(k) for k in KEYS}, f, indent=2)
    for k in KEYS:
        s.set_string(k, "disabled")
    Gio.Settings.sync()


def restore():
    s = _settings()
    if os.path.exists(STATE):
        with open(STATE) as f:
            saved = json.load(f)
        for k in KEYS:
            if k in saved:
                s.set_string(k, saved[k])
        os.remove(STATE)
    else:                          # sin respaldo: valores de fábrica de Marco
        for k in KEYS:
            s.reset(k)
    Gio.Settings.sync()
    return {k: s.get_string(k) for k in KEYS}
