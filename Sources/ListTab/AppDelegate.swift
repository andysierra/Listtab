import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let switcher = Switcher()
    private var statusItem: NSStatusItem!
    private var retry: Timer?
    private let demo = CommandLine.arguments.contains("--show")
    private var backdrop: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Keyboard.shared.switcher = switcher
        setupMenu()
        setupSignals()

        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        tryInstall()
        retry = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tryInstall() }

        // --show: abre el panel unos segundos para ver el diseno sin usar el teclado.
        // Con --demo usa ventanas ficticias sobre un fondo propio (capturas del README).
        if demo {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                var wins: [SwitchWindow]? = nil
                if Demo.enabled {
                    backdrop = Demo.makeBackdrop(); backdrop?.orderFrontRegardless()
                    wins = Demo.windows(count: Demo.intArg("count", default: 7))
                }
                switcher.begin(reverse: false, demo: wins, select: Demo.enabled ? Demo.intArg("select", default: 1) : nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
                    let f = switcher.panelFrame, h = (NSScreen.main ?? NSScreen.screens[0]).frame.height
                    print("FRAME \(Int(f.minX)) \(Int(h - f.maxY)) \(Int(f.width)) \(Int(f.height))")
                    fflush(stdout)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(Demo.intArg("hold", default: 6))) { NSApp.terminate(nil) }
            }
        }
    }

    private func tryInstall() {
        if demo { retry?.invalidate(); return }
        if Keyboard.shared.install() { retry?.invalidate() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Keyboard.shared.uninstall()   // devuelve el ⌘Tab nativo
    }

    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = Self.menuBarIcon()
        let menu = NSMenu()
        menu.addItem(withTitle: "ListTab", action: nil, keyEquivalent: "").isEnabled = false
        menu.addItem(.separator())
        menu.addItem(withTitle: "Salir y restaurar ⌘Tab", action: #selector(quit), keyEquivalent: "q").target = self
        statusItem.menu = menu
    }

    /// Glifo de barra de menu: lista de 3 filas con la del medio resaltada. Template = se adapta a claro/oscuro.
    private static func menuBarIcon() -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setFill(); NSColor.black.setStroke()
            let frame = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 2.5, width: 15, height: 13), xRadius: 3, yRadius: 3)
            frame.lineWidth = 1.3; frame.stroke()
            for (i, y) in [11.2, 7.8, 4.4].enumerated() {
                if i == 1 {   // fila seleccionada: barra rellena de lado a lado
                    NSBezierPath(roundedRect: NSRect(x: 3.4, y: y - 0.6, width: 11.2, height: 3), xRadius: 1.2, yRadius: 1.2).fill()
                } else {
                    NSBezierPath(roundedRect: NSRect(x: 4.6, y: y, width: 8.8, height: 1.5), xRadius: 0.75, yRadius: 0.75).fill()
                }
            }
            return true
        }
        img.isTemplate = true
        return img
    }

    @objc private func quit() { NSApp.terminate(nil) }

    /// Que SIGTERM/SIGINT/SIGHUP tambien restauren el ⌘Tab nativo.
    private func setupSignals() {
        for sig in [SIGTERM, SIGINT, SIGHUP] {
            signal(sig, SIG_IGN)
            let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
            src.setEventHandler { NSApp.terminate(nil) }
            src.resume()
            signalSources.append(src)
        }
    }
    private var signalSources: [DispatchSourceSignal] = []
}
