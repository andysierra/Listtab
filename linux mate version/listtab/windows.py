"""Ventanas: listar, enfocar y cerrar, con libwnck (la misma biblioteca que usa el panel de MATE)."""
import os
import signal
from dataclasses import dataclass, field

from gi.repository import Gio, GdkPixbuf, Gtk, Wnck

from listtab.recency import shared as recency

ICON_SIZE = 64   # se cargan grandes y se escalan al dibujar (la fila cambia de alto)


@dataclass
class SwitchWindow:
    pid: int
    xid: int
    app_name: str
    title: str
    icon: GdkPixbuf.Pixbuf = None
    minimized: bool = False
    window: Wnck.Window = field(default=None, repr=False)   # None en --demo


# --- Nombre e ícono de la app: el .desktop que corresponde a la ventana (WM_CLASS) -----------------

_apps = None      # clave en minúsculas -> Gio.DesktopAppInfo
_icons = {}       # nombre de clase -> pixbuf


def _app_index():
    global _apps
    if _apps is None:
        _apps = {}
        for info in Gio.AppInfo.get_all():
            if not isinstance(info, Gio.DesktopAppInfo):
                continue
            wm = info.get_startup_wm_class()
            if wm:
                _apps.setdefault(wm.lower(), info)
            app_id = (info.get_id() or "").removesuffix(".desktop").lower()
            if app_id:
                _apps.setdefault(app_id, info)
            exe = os.path.basename((info.get_executable() or "")).lower()
            if exe:
                _apps.setdefault(exe, info)
    return _apps


def app_info(w):
    idx = _app_index()
    for key in (w.get_class_group_name(), w.get_class_instance_name()):
        if key and key.lower() in idx:
            return idx[key.lower()]
    return None


def themed_icon(name_or_gicon, size=ICON_SIZE):
    theme = Gtk.IconTheme.get_default()
    try:
        if isinstance(name_or_gicon, str):
            info = theme.lookup_icon(name_or_gicon, size, Gtk.IconLookupFlags.FORCE_SIZE)
        else:
            info = theme.lookup_by_gicon(name_or_gicon, size, Gtk.IconLookupFlags.FORCE_SIZE)
        return info.load_icon() if info else None
    except Exception:
        return None


def _icon_and_name(w):
    key = w.get_class_group_name() or str(w.get_xid())
    info = app_info(w)
    name = info.get_name() if info else (w.get_class_group_name() or w.get_application().get_name() or "?")
    if key not in _icons:
        pix = themed_icon(info.get_icon()) if info and info.get_icon() else None
        if pix is None:   # sin .desktop: el ícono que publica la propia ventana (_NET_WM_ICON)
            pix = w.get_icon()
        _icons[key] = pix
    return _icons[key], name


# --- Listar ----------------------------------------------------------------------------------------

def _screen():
    s = Wnck.Screen.get_default()
    s.force_update()
    return s


def list_windows():
    """Ventanas del escritorio actual (también las minimizadas), de la más reciente a la más antigua.
    Orden: MRU por ventana (Recency); las que nunca tuvieron foco, por apilado (z-order)."""
    screen = _screen()
    stacked = screen.get_windows_stacked()                       # fondo -> frente
    z = {w.get_xid(): i for i, w in enumerate(reversed(stacked))}  # 0 = frente
    recency.seed(sorted(z, key=z.get))
    recency.touch_active()   # la ventana actual siempre va primera

    ws = screen.get_active_workspace()
    items = []
    for w in stacked:
        if w.get_xid() in recency.ignore or w.is_skip_tasklist():
            continue
        if w.get_window_type() not in (Wnck.WindowType.NORMAL, Wnck.WindowType.DIALOG):
            continue
        if ws is not None and not w.is_on_workspace(ws):
            continue   # otro escritorio virtual: fuera (igual que los otros Spaces en macOS)
        icon, app_name = _icon_and_name(w)
        title = w.get_name() or app_name
        pid = w.get_pid() or (w.get_application().get_pid() if w.get_application() else 0)
        items.append((z.get(w.get_xid(), 1 << 30), SwitchWindow(pid, w.get_xid(), app_name, title, icon,
                                                                   w.is_minimized(), w)))

    def key(entry):
        zpos, sw = entry
        r = recency.rank(sw.xid)
        # con historial antes que sin historial; entre las primeras MRU, entre las segundas z-order
        return (0, r) if r is not None else (1, zpos)

    return [sw for _, sw in sorted(items, key=key)]


# --- Acciones --------------------------------------------------------------------------------------

def focus(sw, timestamp):
    recency.touch(sw.xid)   # anotar ya: la señal de foco llega unos ms después
    w = sw.window
    if w is None:
        return
    if w.is_minimized():
        w.unminimize(timestamp)
    w.activate(timestamp)


def close(sw, timestamp):
    """Cierre normal (_NET_CLOSE_WINDOW, como la ✕ de la barra de título). Si la app pregunta si guardar,
    la ventana sigue ahí y el siguiente refresco de la lista la vuelve a mostrar."""
    if sw.window is not None:
        sw.window.close(timestamp)


def quit_app(sw, timestamp):
    """Cierra la app entera: SIGTERM al proceso (cierre ordenado). Sin PID: cierra sus ventanas."""
    if sw.pid and sw.pid != os.getpid():
        try:
            os.kill(sw.pid, signal.SIGTERM)
            return
        except OSError:
            pass
    if sw.window is not None and sw.window.get_class_group() is not None:
        for w in sw.window.get_class_group().get_windows():
            w.close(timestamp)
