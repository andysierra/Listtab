"""Panel: ventana GTK "popup" (override-redirect: sin decoración, encima de todo, no roba el foco)
dibujada con cairo + Pango para reproducir el diseño de la versión macOS (NSPanel HUD + SwiftUI).

Geometría idéntica a PanelView.swift: ancho 600, fila de 36 px que se ENCOGE (hasta 16) para que
todas las ventanas quepan sin scroll, separación 2, padding 10, esquinas 14 (panel) y 8 (fila).
"""
import math

import cairo
from gi.repository import Gdk, GdkX11, Gtk, Pango, PangoCairo

from listtab.recency import shared as recency

MAX_ROW = 36
MIN_ROW = 16
SPACING = 2
PADDING = 20          # 10 arriba + 10 abajo (y a los lados)
WIDTH = 600
RADIUS = 14
SHADOW = 28           # margen transparente alrededor para la sombra

ACCENT = (52 / 255, 120 / 255, 246 / 255)           # azul de selección (accentColor de macOS)
PANEL_BG = (0.165, 0.180, 0.255, 0.94)              # material HUD oscuro
BORDER = (1, 1, 1, 0.12)
PRIMARY = (1, 1, 1, 0.95)
SECONDARY = (235 / 255, 235 / 255, 245 / 255, 0.6)  # secondaryLabel (modo oscuro)
CLOSE_HOVER = (1.0, 0.27, 0.23, 0.9)
ROW_HOVER = (1, 1, 1, 0.08)                         # fila bajo el mouse (no cambia la selección)


def _rounded(cr, x, y, w, h, r):
    r = min(r, w / 2, h / 2)
    cr.new_sub_path()
    cr.arc(x + w - r, y + r, r, -math.pi / 2, 0)
    cr.arc(x + w - r, y + h - r, r, 0, math.pi / 2)
    cr.arc(x + r, y + h - r, r, math.pi / 2, math.pi)
    cr.arc(x + r, y + r, r, math.pi, 3 * math.pi / 2)
    cr.close_path()


def _font_family():
    name = Gtk.Settings.get_default().props.gtk_font_name or "Sans 10"
    return Pango.FontDescription.from_string(name).get_family() or "Sans"


class Panel:
    def __init__(self, model):
        self.model = model
        self.row_h = MAX_ROW
        self.height = 300
        self.scroll = 0
        self.hover_close = None      # índice de la fila con el mouse sobre su ✕
        self.hover_row = None        # índice de la fila bajo el mouse (clic = saltar a esa ventana)
        self._scaled = {}            # (id pixbuf, tamaño) -> pixbuf escalado
        self.family = _font_family()

        self.win = Gtk.Window(type=Gtk.WindowType.POPUP)
        self.win.set_app_paintable(True)
        visual = self.win.get_screen().get_rgba_visual()
        if visual is not None:       # con compositor: esquinas redondeadas y transparencia real
            self.win.set_visual(visual)
        self.area = Gtk.DrawingArea()
        self.area.add_events(Gdk.EventMask.POINTER_MOTION_MASK | Gdk.EventMask.BUTTON_PRESS_MASK
                             | Gdk.EventMask.LEAVE_NOTIFY_MASK)
        self.area.connect("draw", self._draw)
        self.area.connect("motion-notify-event", self._motion)
        self.area.connect("leave-notify-event", self._leave)
        self.area.connect("button-press-event", self._click)
        self.area.set_has_tooltip(True)
        self.area.connect("query-tooltip", self._tooltip)
        self.win.add(self.area)
        self.win.realize()           # para tener XID (no se anota en el MRU) y hora del servidor X
        recency.ignore.add(self.win.get_window().get_xid())

    # --- API -------------------------------------------------------------------------------------

    def server_time(self):
        return GdkX11.x11_get_server_time(self.win.get_window())

    def frame(self):
        """Rectángulo del panel (sin la sombra), coordenadas de pantalla."""
        x, y = self.win.get_position()
        return x + SHADOW, y + SHADOW, WIDTH, self.height

    def show(self, count):
        display = Gdk.Display.get_default()
        _, px, py = display.get_default_seat().get_pointer().get_position()
        monitor = display.get_monitor_at_point(px, py) or display.get_primary_monitor()
        geo, work = monitor.get_geometry(), monitor.get_workarea()
        n = max(count, 1)
        # Todas las ventanas caben: la fila se achica hasta lo necesario (sin scroll).
        available = work.height * 0.92 - PADDING - (n - 1) * SPACING
        self.row_h = min(MAX_ROW, max(MIN_ROW, math.floor(available / n)))
        self.height = int(min(n * self.row_h + (n - 1) * SPACING + PADDING, work.height * 0.92))
        self._scroll_to_selected()
        w, h = WIDTH + 2 * SHADOW, self.height + 2 * SHADOW
        self.win.resize(w, h)
        self.win.move(geo.x + (geo.width - WIDTH) // 2 - SHADOW, geo.y + (geo.height - self.height) // 2 - SHADOW)
        self.win.show_all()
        self.redraw()

    def redraw(self):
        self._scroll_to_selected()
        self.area.queue_draw()

    def hide(self):
        self.hover_close = self.hover_row = None
        self.win.hide()

    # --- geometría de filas ------------------------------------------------------------------------

    def _scroll_to_selected(self):
        """Solo si ni con la fila mínima caben todas (cientos de ventanas): seguir a la seleccionada."""
        content = len(self.model.items) * (self.row_h + SPACING) - SPACING + PADDING
        if content <= self.height:
            self.scroll = 0
            return
        top = PADDING // 2 + self.model.selected * (self.row_h + SPACING)
        if top - self.scroll < PADDING // 2:
            self.scroll = top - PADDING // 2
        elif top + self.row_h - self.scroll > self.height - PADDING // 2:
            self.scroll = top + self.row_h - self.height + PADDING // 2

    def _row_rect(self, i):
        return (SHADOW + 10, SHADOW + 10 + i * (self.row_h + SPACING) - self.scroll, WIDTH - 20, self.row_h)

    def _close_rect(self, i):
        x, y, w, h = self._row_rect(i)
        size = min(max(h - 12, 12), 22)
        return x + w - 10 - size, y + (h - size) / 2, size

    def _hit_row(self, mx, my):
        for i in range(len(self.model.items)):
            x, y, w, h = self._row_rect(i)
            if x <= mx <= x + w and y <= my <= y + h and SHADOW <= my <= SHADOW + self.height:
                return i
        return None

    def _hit_close(self, mx, my):
        for i in range(len(self.model.items)):
            cx, cy, size = self._close_rect(i)
            if cx <= mx <= cx + size and cy <= my <= cy + size:
                return i
        return None

    # --- eventos de mouse ----------------------------------------------------------------------------

    def _motion(self, _w, ev):
        close, row = self._hit_close(ev.x, ev.y), self._hit_row(ev.x, ev.y)
        if (close, row) != (self.hover_close, self.hover_row):
            if (row is None) != (self.hover_row is None):   # mano sobre las filas, flecha fuera
                cursor = Gdk.Cursor.new_from_name(self.win.get_display(), "pointer") if row is not None else None
                self.win.get_window().set_cursor(cursor)
            self.hover_close, self.hover_row = close, row
            self.area.queue_draw()

    def _leave(self, *_):
        if self.hover_close is not None or self.hover_row is not None:
            self.hover_close = self.hover_row = None
            self.win.get_window().set_cursor(None)
            self.area.queue_draw()

    def _click(self, _w, ev):
        if ev.button != 1:
            return False
        hit = self._hit_close(ev.x, ev.y)
        if hit is not None and self.model.on_close:
            # Shift + clic = cerrar la app entera (en macOS era ⌥, pero aquí Alt es la tecla que se mantiene)
            self.model.on_close(hit, bool(ev.state & Gdk.ModifierType.SHIFT_MASK), ev.time)
            return True
        row = self._hit_row(ev.x, ev.y)
        if row is not None and self.model.on_pick:
            self.model.on_pick(row, ev.time)   # clic en la fila = saltar a esa ventana
        return True

    def _tooltip(self, _w, x, y, _kbd, tooltip):
        if self._hit_close(x, y) is None:
            return False
        tooltip.set_text("Cerrar ventana (⇧ clic: cerrar la app)")
        return True

    # --- dibujo ----------------------------------------------------------------------------------------

    def _layout(self, cr, text, size, bold):
        layout = PangoCairo.create_layout(cr)
        desc = Pango.FontDescription.from_string(self.family)
        desc.set_absolute_size(size * Pango.SCALE)
        desc.set_weight(Pango.Weight.MEDIUM if bold else Pango.Weight.NORMAL)
        layout.set_font_description(desc)
        layout.set_text(text, -1)
        layout.set_ellipsize(Pango.EllipsizeMode.MIDDLE)
        return layout

    def _icon(self, pix, size):
        key = (id(pix), size)
        if key not in self._scaled:
            from gi.repository import GdkPixbuf
            self._scaled[key] = pix.scale_simple(size, size, GdkPixbuf.InterpType.HYPER)
        return self._scaled[key]

    def _draw(self, _w, cr):
        cr.set_operator(cairo.OPERATOR_SOURCE)
        cr.set_source_rgba(0, 0, 0, 0)
        cr.paint()
        cr.set_operator(cairo.OPERATOR_OVER)

        # sombra suave (capas concéntricas, un poco desplazada hacia abajo)
        for k in range(1, SHADOW, 2):
            _rounded(cr, SHADOW - k, SHADOW - k + 6, WIDTH + 2 * k, self.height + 2 * k, RADIUS + k)
            cr.set_source_rgba(0, 0, 0, 0.022 * (1 - k / SHADOW))
            cr.fill()

        _rounded(cr, SHADOW, SHADOW, WIDTH, self.height, RADIUS)
        cr.set_source_rgba(*PANEL_BG)
        cr.fill_preserve()
        cr.save()
        cr.clip()
        for i, w in enumerate(self.model.items):
            self._draw_row(cr, i, w)
        cr.restore()
        _rounded(cr, SHADOW + 0.5, SHADOW + 0.5, WIDTH - 1, self.height - 1, RADIUS)
        cr.set_source_rgba(*BORDER)
        cr.set_line_width(1)
        cr.stroke()
        return True

    def _draw_row(self, cr, i, w):
        x, y, rw, h = self._row_rect(i)
        if y + h < SHADOW or y > SHADOW + self.height:
            return
        selected = i == self.model.selected
        if selected:
            _rounded(cr, x, y, rw, h, 8)
            cr.set_source_rgb(*ACCENT)
            cr.fill()
        elif i == self.hover_row:
            _rounded(cr, x, y, rw, h, 8)
            cr.set_source_rgba(*ROW_HOVER)
            cr.fill()

        font = min(max(h * 0.4, 10), 14)
        icon = max(h - 12, 12)
        cx = x + 10
        if w.icon is not None:
            Gdk.cairo_set_source_pixbuf(cr, self._icon(w.icon, int(icon)), cx, y + (h - icon) / 2)
            cr.paint()
        title_x = cx + icon + 10

        close_x, close_y, csize = self._close_rect(i)
        app_text = " · ".join([w.app_name] + ([w.workspace] if w.workspace else [])
                              + (["minimizada"] if w.minimized else []))
        app = self._layout(cr, app_text, max(font - 2, 9), False)
        app.set_ellipsize(Pango.EllipsizeMode.NONE)
        aw, ah = app.get_pixel_size()
        app_x = close_x - 10 - aw
        cr.move_to(app_x, y + (h - ah) / 2)
        cr.set_source_rgba(*((1, 1, 1, 0.8) if selected else SECONDARY))
        PangoCairo.show_layout(cr, app)

        title = self._layout(cr, w.title, font, True)
        title.set_width(int(max(app_x - 12 - title_x, 20) * Pango.SCALE))
        _, th = title.get_pixel_size()
        cr.move_to(title_x, y + (h - th) / 2)
        cr.set_source_rgba(*((1, 1, 1, 1) if selected else PRIMARY))
        PangoCairo.show_layout(cr, title)

        # ✕: círculo rojo al pasar el mouse
        hover = self.hover_close == i
        mid_x, mid_y = close_x + csize / 2, close_y + csize / 2
        if hover:
            cr.arc(mid_x, mid_y, csize / 2, 0, 2 * math.pi)
            cr.set_source_rgba(*CLOSE_HOVER)
            cr.fill()
        arm = csize * 0.18
        cr.set_line_width(max(1.6, csize * 0.09))
        cr.set_line_cap(cairo.LINE_CAP_ROUND)
        cr.move_to(mid_x - arm, mid_y - arm)
        cr.line_to(mid_x + arm, mid_y + arm)
        cr.move_to(mid_x + arm, mid_y - arm)
        cr.line_to(mid_x - arm, mid_y + arm)
        cr.set_source_rgba(*((1, 1, 1, 1) if hover else (1, 1, 1, 0.85) if selected else SECONDARY))
        cr.stroke()
