"""ListTab para Linux (MATE / X11): Alt+Tab con una lista de ventanas y sus títulos completos."""
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GdkX11", "3.0")
gi.require_version("GdkPixbuf", "2.0")
gi.require_version("Wnck", "3.0")
gi.require_version("Pango", "1.0")
gi.require_version("PangoCairo", "1.0")

__version__ = "0.1.0"
