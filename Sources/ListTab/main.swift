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

// --selftest: reproduce el bug del MRU con ventanas reales usando el MISMO camino de ListTab
// (Windows.focus). Requiere 2 ventanas de iTerm con titulo "yazi…" y una de Google Chrome.
// Secuencia: B -> Chrome -> A  =>  el orden debe quedar A, Chrome, B (no A, B, Chrome).
if args.contains("--selftest") {
    guard AXIsProcessTrusted() else { print("Sin permiso de Accesibilidad"); exit(1) }
    func pump(_ s: Double) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }
    Recency.shared.start(); pump(0.5)
    let l = Windows.list()
    let yazis = l.filter { $0.appName == "iTerm2" && $0.title.hasPrefix("yazi") }
    guard yazis.count >= 2, let c = l.first(where: { $0.appName == "Google Chrome" }) else {
        print("faltan ventanas (2 de iTerm 'yazi…' y 1 de Chrome)"); exit(2)
    }
    let a = yazis[0], b = yazis[1]
    for w in [b, c, a] { Windows.focus(w); pump(1.5) }
    let r = Windows.list().prefix(3).map { $0.windowID }
    print("esperado: A=\(a.windowID) Chrome=\(c.windowID) B=\(b.windowID)")
    print("obtenido: \(Array(r))")
    let ok = r == [a.windowID, c.windowID, b.windowID]
    print(ok ? "OK" : "FALLA")
    exit(ok ? 0 : 1)
}

// --track[=N]: sigue el foco N segundos (def. 8) y luego imprime el orden MRU. Para probar el seguimiento.
if let t = args.first(where: { $0.hasPrefix("--track") }) {
    guard AXIsProcessTrusted() else { print("Sin permiso de Accesibilidad"); exit(1) }
    let secs = Double(t.split(separator: "=").last ?? "") ?? 8
    Recency.shared.start()
    RunLoop.main.run(until: Date().addingTimeInterval(secs))
    for (i, w) in Windows.list().enumerated() { print("\(i)\t\(w.appName)\t\(w.title)") }
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
