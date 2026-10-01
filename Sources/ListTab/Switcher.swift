import AppKit

/// Estado del switcher. Todo ocurre en el hilo principal.
final class Switcher {
    let model = ListModel()
    private lazy var panel = SwitcherPanel(model: model)
    var panelFrame: NSRect { panel.frame }
    private(set) var active = false
    private var showWork: DispatchWorkItem?

    /// Se llama al pulsar ⌘Tab / ⌘⇧Tab estando inactivo.
    func begin(reverse: Bool, demo: [SwitchWindow]? = nil, select: Int? = nil) {
        let wins = demo ?? Windows.list()
        guard !wins.isEmpty else { return }
        model.items = wins
        model.selected = select ?? (wins.count > 1 ? (reverse ? wins.count - 1 : 1) : 0)
        active = true
        Keyboard.shared.setActive(true)
        // Panel con retardo: un ⌘Tab rapido cambia de ventana sin parpadeo.
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.active else { return }
            self.panel.show(count: self.model.items.count)
        }
        showWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }

    func step(_ delta: Int) {
        guard active, !model.items.isEmpty else { return }
        let n = model.items.count
        model.selected = ((model.selected + delta) % n + n) % n
    }

    func commit() {
        guard active else { return }
        let target = model.items.indices.contains(model.selected) ? model.items[model.selected] : nil
        end()
        if let target { Windows.focus(target) }
    }

    func cancel() { end() }

    private func end() {
        active = false
        showWork?.cancel()
        panel.hide()
        Keyboard.shared.setActive(false)
    }
}
