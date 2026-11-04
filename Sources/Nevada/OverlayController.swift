import AppKit
import SpriteKit
import Combine

/// Ventana transparente que cubre toda una pantalla, por encima de la barra de menús,
/// y deja pasar todos los clics.
final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // Sin esto, macOS empujaría la ventana por debajo de la barra de menús.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

/// Crea una capa de nieve por pantalla y la rehace cuando cambian las pantallas.
@MainActor
final class OverlayController {
    private var windows: [OverlayWindow] = []
    private var cancellables: Set<AnyCancellable> = []

    func start() {
        rebuild()

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in MainActor.assumeIsolated { self?.rebuild() } }
            .store(in: &cancellables)

        SnowSettings.shared.$isSnowing
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in MainActor.assumeIsolated { self?.wake() } }
            .store(in: &cancellables)
    }

    private func rebuild() {
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()

        for screen in NSScreen.screens {
            let frame = screen.frame
            let window = OverlayWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.setFrame(frame, display: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.isReleasedWhenClosed = false
            // Por encima de los iconos de la barra de menús, por debajo de los menús desplegables.
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
            window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

            let view = SKView(frame: NSRect(origin: .zero, size: frame.size))
            view.allowsTransparency = true
            view.ignoresSiblingOrder = true
            view.preferredFramesPerSecond = 60
            view.autoresizingMask = [.width, .height]

            let menuBarHeight = max(0, frame.maxY - screen.visibleFrame.maxY)
            let scene = SnowScene(size: frame.size, screenFrame: frame, menuBarHeight: menuBarHeight)
            scene.onIdle = { [weak view] in view?.isPaused = true }
            view.presentScene(scene)

            window.contentView = view
            window.orderFrontRegardless()
            windows.append(window)
        }
    }

    private func wake() {
        for window in windows {
            guard let view = window.contentView as? SKView, view.isPaused else { continue }
            (view.scene as? SnowScene)?.resume()
            view.isPaused = false
        }
    }
}
