"""Estado del switcher. Todo ocurre en el hilo principal (GTK)."""
from gi.repository import GLib

from listtab import log, windows
from listtab.panel import Panel


class ListModel:
    def __init__(self):
        self.items = []          # [SwitchWindow]
        self.selected = 0
        self.on_close = None     # (índice de fila, cerrar la app entera) -> lo asigna el Switcher


def _desc(w):
    return f"{w.xid:#x}[{w.app_name}:{w.title}]"


class Switcher:
    def __init__(self):
        self.model = ListModel()
        self.model.on_close = lambda index, quit_app, time: self.close(index, quit_app, time)
        self.panel = Panel(self.model)
        self.keyboard = None     # lo asigna app.py
        self.active = False
        self._show_src = None

    def begin(self, reverse, demo=None, select=None, time=0):
        """Alt+Tab / Alt+Shift+Tab estando inactivo."""
        wins = demo if demo is not None else windows.list_windows()
        if not wins:
            if self.keyboard:
                self.keyboard.set_active(False)
            return
        self.model.items = wins
        if select is not None:
            self.model.selected = select
        else:
            self.model.selected = (len(wins) - 1 if reverse else 1) if len(wins) > 1 else 0
        self.active = True
        log.write(lambda: f"begin sel={self.model.selected} :: " + " | ".join(_desc(w) for w in wins[:5]))

        # Panel con retardo: un Alt+Tab rápido cambia de ventana sin parpadeo.
        def show():
            self._show_src = None
            if self.active:
                self.panel.show(len(self.model.items))
            return False

        self._show_src = GLib.timeout_add(100, show)

    def step(self, delta):
        if not self.active or not self.model.items:
            return
        n = len(self.model.items)
        self.model.selected = (self.model.selected + delta) % n
        self.panel.redraw()

    def commit(self, time=0):
        if not self.active:
            return
        items, sel = self.model.items, self.model.selected
        target = items[sel] if 0 <= sel < len(items) else None
        log.write(f"commit -> {_desc(target) if target else 'nil'}")
        self._end()
        if target:
            windows.focus(target, time or self.panel.server_time())

    def cancel(self):
        self._end()

    def close_selected(self, quit_app, time=0):
        self.close(self.model.selected, quit_app, time)

    def close(self, index, quit_app, time=0):
        """Cierra la ventana de la fila `index` (o toda su app). La fila desaparece de inmediato y, un
        instante después, se relee el estado real: si la app no la dejó cerrar (¿guardar cambios?), reaparece."""
        items = self.model.items
        if not self.active or not 0 <= index < len(items):
            return
        target = items[index]
        keep = items[self.model.selected].xid if 0 <= self.model.selected < len(items) else None
        log.write(f"close {'app' if quit_app else 'window'} {_desc(target)}")
        ts = time or self.panel.server_time()
        if quit_app:
            windows.quit_app(target, ts)
            self.model.items = [w for w in items if w.pid != target.pid]
        else:
            windows.close(target, ts)
            self.model.items = items[:index] + items[index + 1:]
        self._reselect(keep, index)
        GLib.timeout_add(400, self._refresh)

    def _refresh(self):
        """Relee las ventanas reales manteniendo la selección sobre la misma ventana."""
        if self.active and self.model.items and self.model.items[0].window is not None:
            items = self.model.items
            keep = items[self.model.selected].xid if 0 <= self.model.selected < len(items) else None
            self.model.items = windows.list_windows()
            self._reselect(keep, self.model.selected)
        return False

    def _reselect(self, keep_xid, fallback):
        items = self.model.items
        if not items:
            self.cancel()
            return
        idx = next((i for i, w in enumerate(items) if w.xid == keep_xid), None)
        self.model.selected = idx if idx is not None else min(max(fallback, 0), len(items) - 1)
        self.panel.show(len(items))   # reajusta alto y tamaño de fila

    def _end(self):
        self.active = False
        if self._show_src:
            GLib.source_remove(self._show_src)
            self._show_src = None
        self.panel.hide()
        if self.keyboard:
            self.keyboard.set_active(False)
