"""Abrir al iniciar sesión (equivalente a SMAppService.mainApp).

- Instalado con el .deb: hay un autoarranque de SISTEMA en /etc/xdg/autostart/listtab.desktop, así que
  viene activado. Desactivarlo crea una anulación del usuario (~/.config/autostart/listtab.desktop con
  Hidden=true), que es como lo hace el propio MATE.
- Desde el código fuente (sin el de sistema): se crea/borra ~/.config/autostart/listtab.desktop.
"""
import os
import shutil
import sys

PATH = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "autostart", "listtab.desktop")
SYSTEM = [os.path.join(d, "autostart", "listtab.desktop")
          for d in (os.environ.get("XDG_CONFIG_DIRS") or "/etc/xdg").split(":")]


def _command():
    # Ruta absoluta al lanzador junto al paquete: la sesión de MATE puede no tener ~/.local/bin en el PATH.
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    launcher = os.path.join(root, "bin", "listtab")
    if os.path.exists(launcher):
        return launcher
    return shutil.which("listtab") or f"env PYTHONPATH={root} {sys.executable} -m listtab"


def _quote(cmd):
    """Exec= de un .desktop: una ruta con espacios (p. ej. "linux mate version/") va entre comillas."""
    return f'"{cmd}"' if " " in cmd and not cmd.startswith("env ") else cmd


def _system_entry():
    return next((p for p in SYSTEM if os.path.exists(p)), None)


def _hidden(path):
    try:
        with open(path) as f:
            return any(line.strip().lower() in ("hidden=true", "x-mate-autostart-enabled=false") for line in f)
    except OSError:
        return False


def enabled():
    if os.path.exists(PATH):
        return not _hidden(PATH)
    return _system_entry() is not None


def set_enabled(on):
    os.makedirs(os.path.dirname(PATH), exist_ok=True)
    if _system_entry():
        if on:
            if os.path.exists(PATH):
                os.remove(PATH)                   # vuelve a regir el de sistema
        else:
            with open(PATH, "w") as f:           # anulación del usuario
                f.write("[Desktop Entry]\nType=Application\nName=ListTab\nExec=listtab\nHidden=true\n")
    elif on:
        with open(PATH, "w") as f:
            f.write("[Desktop Entry]\nType=Application\nName=ListTab\n"
                    "Comment=Alt+Tab con lista de ventanas\n"
                    f"Exec={_quote(_command())}\nIcon=listtab\nX-MATE-Autostart-enabled=true\nNoDisplay=true\n")
    elif os.path.exists(PATH):
        os.remove(PATH)
    return enabled()
