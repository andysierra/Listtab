import AppKit
import ServiceManagement

let args = CommandLine.arguments

// --restore-native: red de seguridad si la app murio con el ⌘Tab nativo apagado.
if args.contains("--restore-native") {
    setNativeCommandTabEnabled(true)
    print("⌘Tab nativo restaurado")
    exit(0)
}

// --login-on / --login-off: abrir (o no) al iniciar sesion, sin pasar por el menu.
if args.contains("--login-on") || args.contains("--login-off") {
    do {
        if args.contains("--login-on") { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        print("inicio de sesion: \(SMAppService.mainApp.status == .enabled ? "activado" : "desactivado")")
    } catch { print("error: \(error.localizedDescription)"); exit(1) }
    exit(0)
}

// --list: imprime las ventanas que veria el switcher (prueba sin teclado).
if args.contains("--list") {
    guard AXIsProcessTrusted() else { print("Sin permiso de Accesibilidad"); exit(1) }
    for (i, w) in Windows.list().enumerated() {
        print("\(i)\t\(w.appName)\t\(w.title)\(w.minimized ? "\t[minimizada]" : "")")
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
