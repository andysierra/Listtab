import AppKit
import SwiftUI

final class ListModel: ObservableObject {
    @Published var items: [SwitchWindow] = []
    @Published var selected = 0
    /// Alto de fila: se encoge para que quepan TODAS las ventanas sin scroll.
    @Published var rowHeight: CGFloat = 36
    /// (indice de fila, cerrar la app entera). Lo asigna el Switcher.
    var onClose: ((Int, Bool) -> Void)?
}

struct ListView: View {
    @ObservedObject var model: ListModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: SwitcherPanel.spacing) {
                    ForEach(Array(model.items.enumerated()), id: \.offset) { i, w in
                        Row(window: w, selected: i == model.selected, height: model.rowHeight) { quitApp in
                            model.onClose?(i, quitApp)
                        }.id(i)
                    }
                }
                .padding(10)
            }
            .onChange(of: model.selected) { _, new in proxy.scrollTo(new) }
        }
    }
}

private struct Row: View {
    let window: SwitchWindow
    let selected: Bool
    let height: CGFloat
    let onClose: (Bool) -> Void   // true = cerrar la app entera

    var body: some View {
        let icon = max(height - 12, 12)
        let font = min(max(height * 0.4, 10), 14)
        HStack(spacing: 10) {
            Image(nsImage: window.icon ?? NSImage())
                .resizable().frame(width: icon, height: icon)
            Text(window.title)
                .font(.system(size: font, weight: .medium))
                .lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 12)
            Text(window.minimized ? "\(window.appName) · minimizada" : window.appName)
                .font(.system(size: max(font - 2, 9)))
                .foregroundStyle(selected ? Color.white.opacity(0.8) : Color.secondary)
                .lineLimit(1)
            CloseButton(size: min(max(height - 12, 12), 22), selected: selected) {
                // ⌥ + clic = salir de la app; clic solo = cerrar esta ventana
                onClose(NSEvent.modifierFlags.contains(.option))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: height)
        .foregroundStyle(selected ? Color.white : Color.primary)
        .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Color.accentColor : Color.clear))
    }
}

private struct CloseButton: View {
    let size: CGFloat
    let selected: Bool
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: size * 0.5, weight: .bold))
                .frame(width: size, height: size)
                .foregroundStyle(hover ? Color.white : (selected ? Color.white.opacity(0.85) : Color.secondary))
                .background(Circle().fill(hover ? Color.red.opacity(0.9) : Color.clear))
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help("Cerrar ventana (⌥ clic: cerrar la app)")
    }
}

/// El panel no activa la app: sin esto el primer clic se pierde en vez de llegar al boton.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

final class SwitcherPanel {
    private let panel: NSPanel
    static let maxRowHeight: CGFloat = 36
    static let minRowHeight: CGFloat = 16
    static let spacing: CGFloat = 2
    static let padding: CGFloat = 20
    static let width: CGFloat = 600

    private let model: ListModel

    init(model: ListModel) {
        self.model = model
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 300),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let fx = NSVisualEffectView()
        fx.material = .hudWindow
        fx.state = .active
        fx.blendingMode = .behindWindow
        fx.wantsLayer = true
        fx.layer?.cornerRadius = 14
        fx.layer?.masksToBounds = true

        let host = FirstMouseHostingView(rootView: ListView(model: model))
        host.translatesAutoresizingMaskIntoConstraints = false
        fx.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: fx.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: fx.trailingAnchor),
            host.topAnchor.constraint(equalTo: fx.topAnchor),
            host.bottomAnchor.constraint(equalTo: fx.bottomAnchor),
        ])
        panel.contentView = fx
    }

    func show(count: Int) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let n = CGFloat(max(count, 1))
        // Todas las ventanas caben: la fila se achica hasta lo necesario (sin scroll).
        let available = screen.visibleFrame.height * 0.92 - Self.padding - (n - 1) * Self.spacing
        let rowHeight = min(Self.maxRowHeight, max(Self.minRowHeight, (available / n).rounded(.down)))
        model.rowHeight = rowHeight
        let height = min(n * rowHeight + (n - 1) * Self.spacing + Self.padding, screen.visibleFrame.height * 0.92)
        let f = screen.frame
        panel.setFrame(NSRect(x: f.midX - Self.width / 2, y: f.midY - height / 2,
                              width: Self.width, height: height), display: true)
        panel.orderFrontRegardless()
    }

    var frame: NSRect { panel.frame }

    func hide() { panel.orderOut(nil) }
}
