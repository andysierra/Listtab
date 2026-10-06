import AppKit
import Carbon

/// Teclado, con la misma arquitectura que AltTab:
///  - ⌘Tab / ⌘⇧Tab: atajos globales de Carbon (+ se apaga el ⌘Tab nativo del Dock).
///  - flagsChanged: tap pasivo de sesion; al soltar ⌘ se confirma la seleccion.
///  - keyDown mientras esta activo: tap activo a nivel HID (el unico que gana a Esc en macOS 26);
///    permanece deshabilitado fuera de una sesion para no tocar el tecleo normal.
final class Keyboard {
    static let shared = Keyboard()
    var switcher: Switcher!

    private var flagsTap: CFMachPort?
    private var keyTap: CFMachPort?
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private(set) var installed = false

    /// Devuelve false si aun no hay permiso de Accesibilidad.
    func install() -> Bool {
        guard !installed else { return true }
        guard AXIsProcessTrusted() else { return false }

        flagsTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.flagsChanged.rawValue),
            callback: { _, type, event, _ in
                if type == .flagsChanged, !event.flags.contains(.maskCommand) {
                    DispatchQueue.main.async { Keyboard.shared.switcher.commit() }
                }
                return Unmanaged.passUnretained(event)
            }, userInfo: nil)

        keyTap = CGEvent.tapCreate(
            tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: { _, type, event, _ in
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let t = Keyboard.shared.keyTap { CGEvent.tapEnable(tap: t, enable: true) }
                    return Unmanaged.passUnretained(event)
                }
                return Keyboard.shared.handleKeyDown(event) ? nil : Unmanaged.passUnretained(event)
            }, userInfo: nil)

        guard let flagsTap, let keyTap else { flagsTap = nil; keyTap = nil; return false }
        for tap in [flagsTap, keyTap] {
            CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
        }
        CGEvent.tapEnable(tap: keyTap, enable: false)

        registerHotKeys()
        setNativeCommandTabEnabled(false)
        installed = true
        return true
    }

    func setActive(_ on: Bool) {
        if let keyTap { CGEvent.tapEnable(tap: keyTap, enable: on) }
    }

    /// true = el evento se traga.
    private func handleKeyDown(_ event: CGEvent) -> Bool {
        guard switcher.active else { return false }
        let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let shift = event.flags.contains(.maskShift)
        DispatchQueue.main.async { [switcher = switcher!] in
            switch code {
            case kVK_Tab:        switcher.step(shift ? -1 : 1)
            case kVK_DownArrow:  switcher.step(1)
            case kVK_UpArrow:    switcher.step(-1)
            case kVK_Escape:     switcher.cancel()
            case kVK_Return, kVK_ANSI_KeypadEnter: switcher.commit()
            case kVK_ANSI_W:     switcher.closeSelected(quitApp: false)   // cerrar la ventana
            case kVK_ANSI_Q:     switcher.closeSelected(quitApp: true)    // cerrar la app entera
            default: break
            }
        }
        return true   // mientras el switcher esta abierto, ninguna tecla llega a las apps
    }

    private func registerHotKeys() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let reverse = id.id == 2
            DispatchQueue.main.async {
                let s = Keyboard.shared.switcher!
                if !s.active { s.begin(reverse: reverse) }   // activo: lo maneja el tap HID
            }
            return noErr
        }, 1, &spec, nil, nil)

        for (id, mods) in [(UInt32(1), cmdKey), (UInt32(2), cmdKey | shiftKey)] {
            var ref: EventHotKeyRef?
            RegisterEventHotKey(UInt32(kVK_Tab), UInt32(mods), EventHotKeyID(signature: OSType(0x4C545442), id: id),
                                GetApplicationEventTarget(), 0, &ref)
            hotKeyRefs.append(ref)
        }
    }

    func uninstall() {
        guard installed else { return }   // solo restaura si ESTA instancia lo apago
        setNativeCommandTabEnabled(true)
        for r in hotKeyRefs { if let r { UnregisterEventHotKey(r) } }
        hotKeyRefs = []
    }
}
