import AppKit
import ApplicationServices

/// Una ventana (o widget) sobre la que puede posarse la nieve.
struct TrackedWindow: Equatable {
    enum Kind { case window, widget }
    let id: CGWindowID
    /// Marco en coordenadas globales de Cocoa (origen abajo a la izquierda de la pantalla principal).
    let frame: CGRect
    let kind: Kind
}

/// Sigue las ventanas visibles de todas las apps, los widgets del escritorio y el Dock.
/// Solo lee posiciones y tamaños; no necesita permiso de grabación de pantalla.
@MainActor
final class WindowTracker {
    static let shared = WindowTracker()

    /// De delante hacia atrás.
    private(set) var windows: [TrackedWindow] = []
    /// Marco del Dock en coordenadas globales de Cocoa, si hay permiso de Accesibilidad.
    private(set) var dockFrame: CGRect?
    /// Cambia cada vez que algo de lo anterior cambia.
    private(set) var version = 0

    private var windowTimer: Timer?
    private var dockTimer: Timer?
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private var widgetHostPIDs: [pid_t: Bool] = [:]
    private static let widgetPadding: CGFloat = 10

    private init() {}

    func start() {
        refreshWindows()
        refreshDock()
        windowTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            MainActor.assumeIsolated { WindowTracker.shared.refreshWindows() }
        }
        dockTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { _ in
            MainActor.assumeIsolated { WindowTracker.shared.refreshDock() }
        }
    }

    // MARK: Ventanas

    private func refreshWindows() {
        guard let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]],
              let primaryHeight = NSScreen.screens.first?.frame.height
        else { return }

        var found: [TrackedWindow] = []
        for entry in info {
            guard let pid = entry[kCGWindowOwnerPID as String] as? pid_t, pid != ownPID,
                  let number = entry[kCGWindowNumber as String] as? CGWindowID,
                  let layer = entry[kCGWindowLayer as String] as? Int,
                  let boundsDict = entry[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { continue }

            let alpha = entry[kCGWindowAlpha as String] as? Double ?? 1
            guard alpha > 0.05, bounds.width >= 60, bounds.height >= 30 else { continue }

            let kind: TrackedWindow.Kind
            if (0..<20).contains(layer) {
                kind = .window
            } else if layer < 0, isWidgetHost(pid), bounds.width < 900, bounds.height < 900 {
                kind = .widget
            } else {
                continue
            }

            // CGWindowList usa origen arriba a la izquierda; Cocoa, abajo a la izquierda.
            var frame = CGRect(x: bounds.minX, y: primaryHeight - bounds.maxY,
                               width: bounds.width, height: bounds.height)
            if kind == .widget {
                // La ventana de cada widget lleva ~10 pt de margen transparente alrededor de la tarjeta visible.
                frame = frame.insetBy(dx: Self.widgetPadding, dy: Self.widgetPadding)
            }
            found.append(TrackedWindow(id: number, frame: frame, kind: kind))
        }

        if found != windows {
            windows = found
            version &+= 1
        }
    }

    /// Los widgets del escritorio los dibuja el proceso del Centro de notificaciones.
    private func isWidgetHost(_ pid: pid_t) -> Bool {
        if let cached = widgetHostPIDs[pid] { return cached }
        let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? ""
        let result = bundleID == "com.apple.notificationcenterui" || bundleID.hasPrefix("com.apple.chrono")
        widgetHostPIDs[pid] = result
        return result
    }

    // MARK: Dock

    private func refreshDock() {
        let newFrame = AXIsProcessTrusted() ? readDockFrame() : nil
        if newFrame != dockFrame {
            dockFrame = newFrame
            version &+= 1
        }
    }

    private func readDockFrame() -> CGRect? {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first,
              let primaryHeight = NSScreen.screens.first?.frame.height
        else { return nil }

        let app = AXUIElementCreateApplication(dock.processIdentifier)
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement]
        else { return nil }

        for child in children {
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            guard (roleRef as? String) == (kAXListRole as String) else { continue }

            var positionRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(child, kAXPositionAttribute as CFString, &positionRef) == .success,
                  AXUIElementCopyAttributeValue(child, kAXSizeAttribute as CFString, &sizeRef) == .success,
                  let positionValue = positionRef, let sizeValue = sizeRef
            else { continue }

            var origin = CGPoint.zero
            var size = CGSize.zero
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin)
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
            guard size.width > 20, size.height > 20 else { continue }

            let frame = CGRect(x: origin.x, y: primaryHeight - origin.y - size.height,
                               width: size.width, height: size.height)

            // Si el Dock se oculta solo y ahora está escondido, no hay dónde posarse.
            // (un Dock oculto reserva solo ~4 pt de pantalla).
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(frame.insetBy(dx: 2, dy: 2)) })
            else { return nil }
            let full = screen.frame, visible = screen.visibleFrame
            let dockReserved = (visible.minY - full.minY) + (visible.minX - full.minX) + (full.maxX - visible.maxX)
            guard dockReserved > 10 else { return nil }
            return frame
        }
        return nil
    }
}
