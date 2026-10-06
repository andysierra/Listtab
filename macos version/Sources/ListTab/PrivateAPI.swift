import ApplicationServices
import CoreGraphics

// APIs privadas que usa AltTab (lwouis/alt-tab-macos, src/macos/api-wrappers/).

/// Id de CGWindow de un AXUIElement de ventana.
@_silgen_name("_AXUIElementGetWindow") @discardableResult
func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

/// Activa/desactiva un atajo simbolico del sistema. 1 = ⌘Tab, 2 = ⌘⇧Tab.
/// OJO: el efecto PERSISTE aunque la app muera -> siempre restaurar al salir.
@_silgen_name("CGSSetSymbolicHotKeyEnabled") @discardableResult
func CGSSetSymbolicHotKeyEnabled(_ hotKey: Int, _ isEnabled: Bool) -> CGError

func setNativeCommandTabEnabled(_ enabled: Bool) {
    CGSSetSymbolicHotKeyEnabled(1, enabled)
    CGSSetSymbolicHotKeyEnabled(2, enabled)
}
