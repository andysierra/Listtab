import AppKit

/// Estado del switcher. Todo ocurre en el hilo principal.
final class Switcher {
    let model = ListModel()
    private lazy var panel = SwitcherPanel(model: model)
    var panelFrame: NSRect { panel.frame }

    init() {
        model.onClose = { [weak self] index, quitApp in self?.close(at: index, quitApp: quitApp) }
    }
    private(set) var active = false
    private var showWork: DispatchWorkItem?
    private var releaseWatch: Timer?

    /// Se llama al pulsar ⌘Tab / ⌘⇧Tab estando inactivo.
    func begin(reverse: Bool, demo: [SwitchWindow]? = nil, select: Int? = nil) {
        let wins = demo ?? Windows.list()
        guard !wins.isEmpty else { return }
        model.items = wins
        model.selected = select ?? (wins.count > 1 ? (reverse ? wins.count - 1 : 1) : 0)
        active = true
        Log.write("begin sel=\(model.selected) :: " + wins.prefix(5).map { "\($0.windowID)[\($0.appName):\($0.title)]" }.joined(separator: " | "))
        Keyboard.shared.setActive(true)
        // Panel con retardo: un ⌘Tab rapido cambia de ventana sin parpadeo.
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.active else { return }
            self.panel.show(count: self.model.items.count)
        }
        showWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)

        // Red de seguridad: si el evento "soltar ⌘" se pierde (toque muy rapido, evento sintetico),
        // el panel quedaria abierto para siempre. Se consulta el estado real del teclado.
        if demo == nil {   // en --demo no hay ⌘ pulsada: el vigilante cerraria el panel al instante
            releaseWatch = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
                if !CGEventSource.flagsState(.combinedSessionState).contains(.maskCommand) { self?.commit() }
            }
        }
    }

    func step(_ delta: Int) {
        guard active, !model.items.isEmpty else { return }
        let n = model.items.count
        model.selected = ((model.selected + delta) % n + n) % n
    }

    func commit() {
        guard active else { return }
        let target = model.items.indices.contains(model.selected) ? model.items[model.selected] : nil
        Log.write("commit -> \(target.map { "\($0.windowID)[\($0.appName):\($0.title)]" } ?? "nil")")
        end()
        if let target { Windows.focus(target) }
    }

    func cancel() { end() }

    func closeSelected(quitApp: Bool) { close(at: model.selected, quitApp: quitApp) }

    /// Cierra la ventana de la fila `index` (o toda su app). La fila desaparece de inmediato y, un
    /// instante despues, se relee el estado real: si la app no la dejo cerrar (¿guardar cambios?), reaparece.
    func close(at index: Int, quitApp: Bool) {
        guard active, model.items.indices.contains(index) else { return }
        let target = model.items[index]
        let keepID = model.items.indices.contains(model.selected) ? model.items[model.selected].windowID : nil
        Log.write("close \(quitApp ? "app" : "window") \(target.windowID)[\(target.appName):\(target.title)]")

        if quitApp {
            NSRunningApplication(processIdentifier: target.pid)?.terminate()
            model.items.removeAll { $0.pid == target.pid }
        } else {
            Windows.close(target)
            model.items.remove(at: index)
        }
        reselect(keeping: keepID, fallback: index)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.refresh() }
    }

    /// Relee las ventanas reales manteniendo la seleccion sobre la misma ventana.
    private func refresh() {
        guard active else { return }
        let keepID = model.items.indices.contains(model.selected) ? model.items[model.selected].windowID : nil
        model.items = Windows.list()
        reselect(keeping: keepID, fallback: model.selected)
    }

    private func reselect(keeping id: CGWindowID?, fallback: Int) {
        guard !model.items.isEmpty else { cancel(); return }
        if let id, let i = model.items.firstIndex(where: { $0.windowID == id }) { model.selected = i }
        else { model.selected = min(max(fallback, 0), model.items.count - 1) }
        panel.show(count: model.items.count)   // reajusta alto y tamano de fila
    }

    private func end() {
        active = false
        releaseWatch?.invalidate(); releaseWatch = nil
        showWork?.cancel()
        panel.hide()
        Keyboard.shared.setActive(false)
    }
}
