import AppKit
import ApplicationServices

/// MRU por VENTANA (no por app). El z-order de macOS no sirve: al activar una app sube TODAS sus
/// ventanas juntas, asi que "iTerm(yazi)" arrastraria a "iTerm(docker)" por encima de Chrome.
/// Aqui solo cuenta la ventana que de verdad tuvo el foco, via notificaciones de Accesibilidad.
final class Recency {
    static let shared = Recency()

    private(set) var order: [CGWindowID] = []          // [0] = la mas reciente
    private var observers: [pid_t: AXObserver] = [:]
    private var settle: [pid_t: DispatchWorkItem] = [:]
    private let me = ProcessInfo.processInfo.processIdentifier

    func touch(_ id: CGWindowID) {
        guard id != 0 else { return }
        order.removeAll { $0 == id }
        order.insert(id, at: 0)
        if order.count > 300 { order.removeLast(order.count - 300) }
    }

    func rank(_ id: CGWindowID) -> Int? { order.firstIndex(of: id) }

    /// Primera vez (o tras un reinicio): arranca con el z-order actual, frente -> fondo.
    func seed(frontToBack ids: [CGWindowID]) {
        guard order.isEmpty else { return }
        order = Array(ids.prefix(300))
    }

    func touchFocusedWindow(of pid: pid_t) {
        let ax = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(ax, 0.2)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(ax, kAXFocusedWindowAttribute as CFString, &ref) == .success,
              let ref else { return }
        var id: CGWindowID = 0
        _AXUIElementGetWindow(ref as! AXUIElement, &id)
        touch(id)
    }

    /// El foco se anota cuando se ASIENTA, no al primer aviso: al reactivar una app macOS enfoca un
    /// instante la ventana que tenia antes (p. ej. iTerm(docker)) y justo despues la que se pidio.
    /// Si anotaramos el primer aviso, esa ventana intermedia se colaria como "reciente".
    func focusSignal(pid: pid_t) {
        settle[pid]?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else { return }
            self.touchFocusedWindow(of: pid)
        }
        settle[pid] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    func touchFrontmost() {
        if let app = NSWorkspace.shared.frontmostApplication, app.processIdentifier != me {
            touchFocusedWindow(of: app.processIdentifier)
        }
    }

    // MARK: - Seguimiento del foco

    func start() {
        for app in NSWorkspace.shared.runningApplications { attach(app) }
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [self] n in
            if let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication { attach(app) }
        }
        nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [self] n in
            if let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                observers.removeValue(forKey: app.processIdentifier)
            }
        }
        nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [self] n in
            if let app = n.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app.processIdentifier != me { focusSignal(pid: app.processIdentifier) }
        }
        touchFrontmost()
    }

    private func attach(_ app: NSRunningApplication) {
        let pid = app.processIdentifier
        guard app.activationPolicy == .regular, pid != me, observers[pid] == nil else { return }
        var obs: AXObserver?
        guard AXObserverCreate(pid, focusCallback, &obs) == .success, let obs else { return }
        let axApp = AXUIElementCreateApplication(pid)
        AXObserverAddNotification(obs, axApp, kAXFocusedWindowChangedNotification as CFString, nil)
        AXObserverAddNotification(obs, axApp, kAXMainWindowChangedNotification as CFString, nil)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .commonModes)
        observers[pid] = obs
    }
}

private let focusCallback: AXObserverCallback = { _, element, _, _ in
    var pid: pid_t = 0
    AXUIElementGetPid(element, &pid)
    Recency.shared.focusSignal(pid: pid)
}
