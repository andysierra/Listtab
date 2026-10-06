"""Abrir al iniciar sesión (equivalente a SMAppService.mainApp): un .desktop en ~/.config/autostart."""
import os
import shutil
import sys

PATH = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "autostart", "listtab.desktop")


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


def enabled():
    return os.path.exists(PATH)


def set_enabled(on):
    if on:
        os.makedirs(os.path.dirname(PATH), exist_ok=True)
        with open(PATH, "w") as f:
            f.write("[Desktop Entry]\nType=Application\nName=ListTab\n"
                    "Comment=Alt+Tab con lista de ventanas\n"
                    f"Exec={_quote(_command())}\nIcon=listtab\nX-MATE-Autostart-enabled=true\nNoDisplay=true\n")
    elif os.path.exists(PATH):
        os.remove(PATH)
    return enabled()
