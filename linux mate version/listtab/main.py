"""Punto de entrada y flags de línea de comandos (los mismos que la versión macOS)."""
import fcntl
import os
import sys
import time

from gi.repository import Gtk

import listtab
from listtab import autostart, native, settings, windows
from listtab.recency import shared as recency

HELP = f"""ListTab {listtab.__version__} — Alt+Tab con una lista de ventanas (MATE / X11)

  listtab                       ejecutar (ícono de bandeja; captura Alt+Tab)
  listtab --restore-native      devuelve el Alt+Tab de MATE si ListTab murió a la fuerza
  listtab --login-on / --login-off   abrir (o no) al iniciar sesión
  listtab --workspaces=all|current   ventanas de todos los escritorios (def.) o solo del actual
  listtab --list                imprime las ventanas que vería el switcher
  listtab --track[=N]           sigue el foco N segundos (def. 8) e imprime el orden MRU
  listtab --selftest            reproduce el escenario MRU por ventana con ventanas reales
  listtab --selftest-close      cierra de verdad 2 ventanas de xed con el mismo código de ListTab
  listtab --show [--demo] [--count=N] [--select=N] [--hold=S]
                                abre el panel unos segundos sin instalar atajos
"""


def pump(seconds):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        while Gtk.events_pending():
            Gtk.main_iteration_do(False)
        time.sleep(0.01)


def _print_list():
    for i, w in enumerate(windows.list_windows()):
        print(f"{i}\t{w.app_name}\t{w.title}" + (f"\t[{w.workspace}]" if w.workspace else "")
              + ("\t[minimizada]" if w.minimized else ""))


def selftest():
    """Secuencia B -> C -> A con A, B de la MISMA app y C de otra  =>  orden esperado A, C, B
    (no A, B, C: al activar A no debe "subir" B solo por ser de la misma app)."""
    recency.start()
    pump(0.5)
    ws = windows.list_windows()
    by_app = {}
    for w in ws:
        by_app.setdefault(w.app_name, []).append(w)
    pair = next((v for v in by_app.values() if len(v) >= 2), None)
    if not pair:
        print("faltan ventanas: hacen falta 2 de una misma app y 1 de otra en este escritorio")
        sys.exit(2)
    a, b = pair[0], pair[1]
    c = next((w for w in ws if w.app_name != a.app_name), None)
    if c is None:
        print("falta una ventana de otra app")
        sys.exit(2)
    from listtab.panel import Panel
    from listtab.switcher import ListModel
    clock = Panel(ListModel())
    for w in (b, c, a):
        windows.focus(w, clock.server_time())
        pump(1.5)
    got = [w.xid for w in windows.list_windows()[:3]]
    print(f"esperado: A={a.xid:#x} ({a.app_name}) C={c.xid:#x} ({c.app_name}) B={b.xid:#x}")
    print(f"obtenido: {[hex(x) for x in got]}")
    ok = got == [a.xid, c.xid, b.xid]
    print("OK" if ok else "FALLA")
    sys.exit(0 if ok else 1)


def selftest_close():
    """Prepara antes 2 ventanas de xed:  xed --new-window & xed --new-window &"""
    from listtab.panel import Panel
    from listtab.switcher import ListModel
    clock = Panel(ListModel())

    def edits():
        return [w for w in windows.list_windows() if w.window and
                (w.window.get_class_group_name() or "").lower() in ("xed", "org.x.editor")]

    before = edits()
    if len(before) < 2:
        print(f"hacen falta 2 ventanas de xed (hay {len(before)})")
        sys.exit(2)
    windows.close(before[0], clock.server_time())
    pump(1.0)
    after_one = len(edits())
    print(f"cerrar ventana: {len(before)} -> {after_one}  {'OK' if after_one == len(before) - 1 else 'FALLA'}")
    windows.quit_app(before[1], clock.server_time())
    pump(2.0)
    after_quit = len(edits())
    print(f"cerrar app:     {after_one} -> {after_quit}  {'OK' if after_quit == 0 else 'FALLA'}")
    sys.exit(0 if after_one == len(before) - 1 and after_quit == 0 else 1)


def _single_instance():
    """Una sola instancia: dos procesos no pueden capturar Alt+Tab a la vez."""
    path = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "listtab.lock")
    lock = open(path, "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        print("ListTab ya está corriendo")
        sys.exit(0)
    return lock


def main():
    args = sys.argv[1:]

    if "--help" in args or "-h" in args:
        print(HELP)
        return
    if "--version" in args:
        print(listtab.__version__)
        return

    # --restore-native: red de seguridad si la app murió con el Alt+Tab nativo apagado.
    if "--restore-native" in args:
        vals = native.restore()
        print("Alt+Tab nativo restaurado: " + ", ".join(f"{k}={v}" for k, v in vals.items()))
        return

    if "--login-on" in args or "--login-off" in args:
        on = autostart.set_enabled("--login-on" in args)
        print(f"inicio de sesión: {'activado' if on else 'desactivado'}")
        return

    ws = next((a for a in args if a.startswith("--workspaces=")), None)
    if ws:
        value = ws.split("=", 1)[1]
        if value not in ("all", "current"):
            print("uso: --workspaces=all|current")
            sys.exit(1)
        settings.set("all_workspaces", value == "all")
        print("ventanas: " + ("de todos los escritorios" if value == "all" else "solo del escritorio actual"))
        return

    if "--selftest" in args:
        selftest()
    if "--selftest-close" in args:
        selftest_close()

    track = next((a for a in args if a.startswith("--track")), None)
    if track:
        secs = float(track.split("=", 1)[1]) if "=" in track else 8
        recency.start()
        pump(secs)
        _print_list()
        return

    if "--list" in args:
        _print_list()
        return

    _lock = _single_instance() if "--show" not in args else None
    from listtab.app import App
    App().run()


if __name__ == "__main__":
    main()
