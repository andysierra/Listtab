"""Teclado, con la misma arquitectura que la versión de macOS, traducida a X11:

  - Alt+Tab / Alt+Shift+Tab: XGrabKey pasivo sobre la ventana raíz (antes se le quita Alt+Tab a Marco,
    ver native.py; mientras Marco lo tenga, el grab devuelve BadAccess y se reintenta).
  - Mientras el switcher está abierto: XGrabKeyboard activo → TODAS las teclas llegan aquí y ninguna a
    las apps (equivale al tap HID activo de macOS). Fuera de una sesión no se toca el tecleo normal.
  - Soltar Alt = confirmar. Red de seguridad: cada 40 ms se mira el estado real de Alt (query_pointer),
    por si el evento de soltar se pierde (toque muy rápido antes de que el grab estuviera activo).

Corre en su propio hilo con su propia conexión X (python-xlib). Nunca toca GTK: le pasa cada acción
al hilo principal con GLib.idle_add.
"""
import queue
import select
import threading

from gi.repository import GLib
from Xlib import X, XK, display, error

from listtab import log

ALT_KEYSYMS = {XK.XK_Alt_L, XK.XK_Alt_R, XK.XK_Meta_L, XK.XK_Meta_R}
# Bloq Mayús y Bloq Num cambian el "state": se registra el atajo con todas sus combinaciones.
LOCKS = [0, X.LockMask, X.Mod2Mask, X.LockMask | X.Mod2Mask]


class Keyboard(threading.Thread):
    def __init__(self, switcher):
        super().__init__(daemon=True, name="listtab-keyboard")
        self.switcher = switcher
        self.d = display.Display()
        self.root = self.d.screen().root
        self.tab = self.d.keysym_to_keycode(XK.XK_Tab)
        self.cmds = queue.Queue()
        self.active = False          # sesión abierta (keyboard grab activo)
        self.committed = False       # ya se mandó commit en esta sesión (el vigilante no repite)
        self.last_time = X.CurrentTime
        self.installed = False

    # --- instalación ----------------------------------------------------------------------------

    def install(self):
        """Devuelve False si Alt+Tab sigue tomado por otro (Marco todavía no lo soltó)."""
        if self.installed:
            return True
        failed = []

        def onerror(*_):
            failed.append(True)

        for mods in (X.Mod1Mask, X.Mod1Mask | X.ShiftMask):
            for lock in LOCKS:
                self.root.grab_key(self.tab, mods | lock, True, X.GrabModeAsync, X.GrabModeAsync,
                                   onerror=onerror)
        self.d.sync()
        if failed:
            self._ungrab_keys()
            self.d.sync()
            log.write("install: Alt+Tab ocupado (BadAccess), se reintenta")
            return False
        self.installed = True
        if not self.is_alive():
            self.start()
        log.write("install: Alt+Tab capturado")
        return True

    def _ungrab_keys(self):
        for mods in (X.Mod1Mask, X.Mod1Mask | X.ShiftMask):
            for lock in LOCKS:
                self.root.ungrab_key(self.tab, mods | lock)

    def uninstall(self):
        if self.installed:
            self.cmds.put("uninstall")

    def set_active(self, on):
        """Lo llama el hilo principal al terminar una sesión (commit/cancel)."""
        if not on:
            self.cmds.put("ungrab")

    # --- bucle del hilo ---------------------------------------------------------------------------

    def run(self):
        fd = self.d.fileno()
        while True:
            select.select([fd], [], [], 0.04)
            while not self.cmds.empty():
                cmd = self.cmds.get()
                if cmd == "ungrab" and self.active:
                    self.d.ungrab_keyboard(X.CurrentTime)
                    self.d.flush()
                    self.active = False
                elif cmd == "uninstall":
                    self._ungrab_keys()
                    self.d.flush()
                    return
            while self.d.pending_events():
                self._handle(self.d.next_event())
            if self.active and not self.committed:
                # vigilante: ¿sigue Alt apretado de verdad?
                if not (self.root.query_pointer().mask & X.Mod1Mask):
                    self._post("commit")

    def _post(self, action, *args):
        if action == "commit":
            self.committed = True
        GLib.idle_add(self._dispatch, action, args, self.last_time)

    def _dispatch(self, action, args, time):
        getattr(self.switcher, action)(*args, time=time) if action in ("begin", "commit", "close_selected") \
            else getattr(self.switcher, action)(*args)
        return False

    def _handle(self, ev):
        if ev.type not in (X.KeyPress, X.KeyRelease):
            return
        self.last_time = ev.time
        keysym = self.d.keycode_to_keysym(ev.detail, 0)
        shift = bool(ev.state & X.ShiftMask)

        if ev.type == X.KeyRelease:
            if self.active and keysym in ALT_KEYSYMS:
                self._post("commit")
            return

        if not self.active:
            if ev.detail == self.tab and ev.state & X.Mod1Mask:
                self.active, self.committed = True, False
                try:   # grab activo: desde ya, ninguna tecla llega a las apps
                    self.root.grab_keyboard(False, X.GrabModeAsync, X.GrabModeAsync, ev.time)
                except error.XError:
                    pass
                self._post("begin", shift)
            return

        if keysym in (XK.XK_Tab, XK.XK_ISO_Left_Tab):
            self._post("step", -1 if (shift or keysym == XK.XK_ISO_Left_Tab) else 1)
        elif keysym == XK.XK_Down:
            self._post("step", 1)
        elif keysym == XK.XK_Up:
            self._post("step", -1)
        elif keysym == XK.XK_Escape:
            self._post("cancel")
        elif keysym in (XK.XK_Return, XK.XK_KP_Enter):
            self._post("commit")
        elif keysym in (XK.XK_w, XK.XK_W):
            self._post("close_selected", False)    # cerrar la ventana
        elif keysym in (XK.XK_q, XK.XK_Q):
            self._post("close_selected", True)     # cerrar la app entera
        # cualquier otra tecla: se traga (mientras el switcher está abierto nada llega a las apps)
