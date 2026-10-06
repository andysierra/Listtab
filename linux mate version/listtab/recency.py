"""MRU por VENTANA (no por app).

El orden de apilado de X sirve para sembrar, pero no como historial: lo que cuenta es qué ventana tuvo
el foco de verdad. Se escucha _NET_ACTIVE_WINDOW (señal "active-window-changed" de Wnck).
"""
from gi.repository import GLib, Wnck

LIMIT = 300


class Recency:
    def __init__(self):
        self.order = []          # [0] = la más reciente (XIDs)
        self.ignore = set()      # XIDs propios (el panel): nunca cuentan
        self._settle = None
        self._screen = None

    def touch(self, xid):
        if not xid or xid in self.ignore:
            return
        if xid in self.order:
            self.order.remove(xid)
        self.order.insert(0, xid)
        del self.order[LIMIT:]

    def rank(self, xid):
        try:
            return self.order.index(xid)
        except ValueError:
            return None

    def seed(self, front_to_back):
        """Primera vez (o tras un reinicio): arranca con el apilado actual, frente -> fondo."""
        if not self.order:
            self.order = [x for x in front_to_back if x not in self.ignore][:LIMIT]

    def touch_active(self):
        screen = self._screen or Wnck.Screen.get_default()
        w = screen.get_active_window()
        if w is not None:
            self.touch(w.get_xid())

    def focus_signal(self):
        """El foco se anota cuando se ASIENTA (150 ms), no al primer aviso: al activar una ventana, el
        gestor puede enfocar un instante otra (p. ej. la anterior de la misma app) y luego la pedida.
        Si se anotara el primer aviso, esa ventana intermedia se colaría como "reciente"."""
        if self._settle:
            GLib.source_remove(self._settle)

        def settle():
            self._settle = None
            self.touch_active()
            return False

        self._settle = GLib.timeout_add(150, settle)

    def start(self):
        self._screen = Wnck.Screen.get_default()
        self._screen.force_update()
        self._screen.connect("active-window-changed", lambda *_: self.focus_signal())
        self._screen.connect("window-closed", lambda _s, w: self.order.remove(w.get_xid())
                             if w.get_xid() in self.order else None)
        self.touch_active()


shared = Recency()
