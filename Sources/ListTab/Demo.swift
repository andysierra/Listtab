import AppKit

/// Modo demo (`--show --demo`): ventanas ficticias sobre un fondo propio, para capturas del README
/// sin mostrar el escritorio real. Uso: ListTab --show --demo [--count=7] [--select=1]
enum Demo {
    static var enabled: Bool { CommandLine.arguments.contains("--demo") }

    static func intArg(_ name: String, default d: Int) -> Int {
        for a in CommandLine.arguments where a.hasPrefix("--\(name)=") {
            if let v = Int(a.dropFirst(name.count + 3)) { return v }
        }
        return d
    }

    private static let pool: [(bundle: String, app: String, title: String)] = [
        ("com.googlecode.iterm2", "iTerm2", "yazi: Desktop"),
        ("com.googlecode.iterm2", "iTerm2", "yazi: dev"),
        ("com.apple.dt.Xcode", "Xcode", "ListTab — Keyboard.swift"),
        ("com.apple.Safari", "Safari", "Hacker News"),
        ("com.apple.mail", "Mail", "Inbox — 3 unread"),
        ("com.apple.Notes", "Notes", "Ideas for the weekend"),
        ("com.apple.finder", "Finder", "Downloads"),
        ("com.apple.iCal", "Calendar", "October 2026"),
        ("com.apple.Terminal", "Terminal", "zsh — 120×32"),
        ("com.apple.Preview", "Preview", "architecture-diagram.png"),
        ("com.apple.MobileSMS", "Messages", "Mom"),
        ("com.apple.Music", "Music", "Library"),
        ("com.apple.systempreferences", "System Settings", "Keyboard"),
        ("com.apple.TextEdit", "TextEdit", "todo.txt"),
        ("com.apple.reminders", "Reminders", "Today"),
        ("com.apple.Maps", "Maps", "Medellín"),
        ("com.apple.Photos", "Photos", "Library"),
        ("com.apple.freeform", "Freeform", "Board 3"),
        ("com.apple.stocks", "Stocks", "Watchlist"),
        ("com.apple.Safari", "Safari", "Apple Developer Documentation"),
        ("com.apple.dt.Xcode", "Xcode", "Package.swift"),
        ("com.apple.Notes", "Notes", "Groceries"),
        ("com.apple.VoiceMemos", "Voice Memos", "New Recording"),
    ]

    static func windows(count: Int) -> [SwitchWindow] {
        (0..<count).map { i in
            let e = pool[i % pool.count]
            let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: e.bundle)
                .map { NSWorkspace.shared.icon(forFile: $0.path) }
            return SwitchWindow(pid: 0, windowID: CGWindowID(i), element: AXUIElementCreateSystemWide(),
                                appName: e.app, title: e.title, icon: icon, minimized: false)
        }
    }

    /// Ventana a pantalla completa con un degradado, justo debajo del panel.
    static func makeBackdrop() -> NSWindow {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let w = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        w.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue - 1)
        w.isOpaque = true
        w.backgroundColor = NSColor(srgbRed: 0.10, green: 0.11, blue: 0.15, alpha: 1)
        w.contentView = Backdrop(frame: screen.frame)
        return w
    }

    private final class Backdrop: NSView {
        override func draw(_ dirtyRect: NSRect) {
            func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
                NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
            }
            NSGradient(colors: [c(26, 27, 38), c(36, 40, 59)])!.draw(in: bounds, angle: -60)
            NSGradient(colors: [c(122, 162, 247, 0.55), c(122, 162, 247, 0)])!
                .draw(fromCenter: NSPoint(x: bounds.width * 0.18, y: bounds.height * 0.85), radius: 0,
                      toCenter: NSPoint(x: bounds.width * 0.18, y: bounds.height * 0.85),
                      radius: bounds.width * 0.55, options: [])
            NSGradient(colors: [c(187, 154, 247, 0.45), c(187, 154, 247, 0)])!
                .draw(fromCenter: NSPoint(x: bounds.width * 0.85, y: bounds.height * 0.1), radius: 0,
                      toCenter: NSPoint(x: bounds.width * 0.85, y: bounds.height * 0.1),
                      radius: bounds.width * 0.5, options: [])
        }
    }
}
