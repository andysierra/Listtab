import AppKit
import ApplicationServices

struct SwitchWindow {
    let pid: pid_t
    let windowID: CGWindowID
    let element: AXUIElement
    let appName: String
    let title: String
    let icon: NSImage?
    let minimized: Bool
}

enum Windows {
    /// Ventanas del Space actual (mas las minimizadas), de la mas reciente a la mas antigua.
    /// Orden: MRU por ventana (Recency); las que nunca tuvieron foco, por z-order de CGWindowList.
    static func list() -> [SwitchWindow] {
        let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        var z: [CGWindowID: Int] = [:]
        for (i, d) in info.enumerated() {
            guard (d[kCGWindowLayer as String] as? Int) == 0,
                  let num = d[kCGWindowNumber as String] as? UInt32 else { continue }
            z[num] = i
        }
        Recency.shared.seed(frontToBack: z.sorted { $0.value < $1.value }.map { $0.key })
        Recency.shared.touchFrontmost()   // la ventana actual siempre va primera

        let me = ProcessInfo.processInfo.processIdentifier
        var all: [(z: Int, w: SwitchWindow)] = []

        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && app.processIdentifier != me && !app.isTerminated {
            let axApp = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(axApp, 0.2)
            guard let wins: [AXUIElement] = attr(axApp, kAXWindowsAttribute) else { continue }
            for w in wins {
                let sub: String? = attr(w, kAXSubroleAttribute)
                guard sub == kAXStandardWindowSubrole as String || sub == kAXDialogSubrole as String else { continue }
                var wid: CGWindowID = 0
                _AXUIElementGetWindow(w, &wid)
                let isMin: Bool = attr(w, kAXMinimizedAttribute) ?? false
                let appName = app.localizedName ?? "?"
                var title: String = attr(w, kAXTitleAttribute) ?? ""
                if title.isEmpty { title = appName }
                let sw = SwitchWindow(pid: app.processIdentifier, windowID: wid, element: w,
                                      appName: appName, title: title, icon: app.icon, minimized: isMin)
                if isMin { all.append((Int.max, sw)) }
                else if let order = z[wid] { all.append((order, sw)) }
                // ni minimizada ni en pantalla (otro Space, app oculta): fuera en la version minima
            }
        }
        let rec = Recency.shared
        return all.sorted { a, b in
            switch (rec.rank(a.w.windowID), rec.rank(b.w.windowID)) {
            case let (x?, y?): return x < y          // ambas con historial: MRU
            case (_?, nil):    return true            // con historial antes que sin historial
            case (nil, _?):    return false
            case (nil, nil):   return a.z < b.z       // sin historial: z-order
            }
        }.map { $0.w }
    }

    static func focus(_ w: SwitchWindow) {
        Recency.shared.touch(w.windowID)   // registrar ya: el AXObserver puede tardar unos ms
        if w.minimized {
            AXUIElementSetAttributeValue(w.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        let axApp = AXUIElementCreateApplication(w.pid)
        AXUIElementSetAttributeValue(axApp, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(w.element, kAXRaiseAction as CFString)
        AXUIElementSetAttributeValue(w.element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(w.element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    }

    private static func attr<T>(_ el: AXUIElement, _ name: String) -> T? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, name as CFString, &ref) == .success else { return nil }
        return ref as? T
    }
}
