"""La app en ejecución: ícono de bandeja, captura de Alt+Tab y restauración del Alt+Tab nativo al salir."""
import os
import signal
import sys

from gi.repository import GLib, Gtk

from listtab import autostart, demo, log, native
from listtab.recency import shared as recency
from listtab.switcher import Switcher

RESOURCES = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "resources")


class App:
    def __init__(self):
        self.switcher = Switcher()
        self.keyboard = None
        self.indicator = None
        self.show_mode = "--show" in sys.argv
        self._backdrop = None

    def run(self):
        for sig in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):   # también restauran Alt+Tab
            GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, sig, self.quit)

        if self.show_mode:
            GLib.timeout_add(500, self._show_demo)
        else:
            self._setup_tray()
            native.disable()
            from listtab.keyboard import Keyboard
            self.keyboard = Keyboard(self.switcher)
            self.switcher.keyboard = self.keyboard
            # Marco suelta Alt+Tab un instante después de cambiar gsettings: reintentar cada segundo.
            if not self._try_install():
                GLib.timeout_add_seconds(1, self._try_install)
        Gtk.main()

    def _try_install(self):
        if self.keyboard.install():
            recency.start()   # MRU por ventana
            GLib.timeout_add_seconds(1, self._watchdog)
            return False
        return True

    def _watchdog(self):
        """Red de seguridad: si el hilo del teclado muriera igual, la conexión X que tenía el teclado
        capturado se cierra con el proceso. Se cierra ListTab ordenadamente (restaura Alt+Tab)."""
        if self.keyboard.is_alive():
            return True
        log.write("watchdog: el hilo del teclado murió; se cierra ListTab y se restaura Alt+Tab")
        self.switcher.cancel()
        self.quit()
        return False

    def quit(self, *_):
        if self.keyboard is not None:
            self.keyboard.uninstall()
            native.restore()   # devuelve el Alt+Tab nativo
            log.write("quit: Alt+Tab nativo restaurado")
        Gtk.main_quit()
        return False

    # --- --show: abre el panel unos segundos para ver el diseño sin usar el teclado -----------------

    def _show_demo(self):
        wins = None
        if demo.enabled():
            self._backdrop = demo.make_backdrop()
            self._backdrop.show_all()
            wins = demo.windows(demo.int_arg("count", 7))
        select = demo.int_arg("select", 1) if demo.enabled() else None
        self.switcher.begin(False, demo=wins, select=select)

        def frame():
            x, y, w, h = self.switcher.panel.frame()
            print(f"FRAME {x} {y} {w} {h}", flush=True)
            return False

        GLib.timeout_add(400, frame)
        GLib.timeout_add_seconds(demo.int_arg("hold", 6), self.quit)
        return False

    # --- ícono de bandeja (equivale a la barra de menú de macOS) -------------------------------------

    def _setup_tray(self):
        menu = Gtk.Menu()
        title = Gtk.MenuItem(label="ListTab")
        title.set_sensitive(False)
        menu.append(title)
        menu.append(Gtk.SeparatorMenuItem())
        login = Gtk.CheckMenuItem(label="Abrir al iniciar sesión")
        login.set_active(autostart.enabled())
        login.connect("toggled", lambda item: item.set_active(autostart.set_enabled(item.get_active())))
        menu.append(login)
        menu.append(Gtk.SeparatorMenuItem())
        quit_item = Gtk.MenuItem(label="Salir y restaurar Alt+Tab")
        quit_item.connect("activate", self.quit)
        menu.append(quit_item)
        menu.show_all()

        icon = os.path.join(RESOURCES, "listtab-tray.svg")
        try:
            import gi
            gi.require_version("AyatanaAppIndicator3", "0.1")
            from gi.repository import AyatanaAppIndicator3 as AI
            self.indicator = AI.Indicator.new("listtab", icon, AI.IndicatorCategory.APPLICATION_STATUS)
            self.indicator.set_status(AI.IndicatorStatus.ACTIVE)
            self.indicator.set_title("ListTab")
            self.indicator.set_menu(menu)
        except (ImportError, ValueError):   # sin AppIndicator: ícono clásico de bandeja
            self.indicator = Gtk.StatusIcon.new_from_file(icon)
            self.indicator.set_tooltip_text("ListTab")
            self.indicator.connect("popup-menu", lambda _i, button, time:
                                   menu.popup(None, None, None, None, button, time))
