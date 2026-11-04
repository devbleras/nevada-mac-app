import AppKit
import SpriteKit
import Combine

/// La nevada de una pantalla: copos cayendo y la nieve que se amontona.
@MainActor
final class SnowScene: SKScene {
    /// Marco de la pantalla en coordenadas globales de Cocoa.
    let screenFrame: CGRect
    let menuBarHeight: CGFloat

    private struct Flake {
        let node: SKSpriteNode
        var position: CGPoint
        var fallSpeed: CGFloat
        var depth: CGFloat
        var phase: CGFloat
        var swayAmount: CGFloat
        var swaySpeed: CGFloat
        var spin: CGFloat
        var amount: CGFloat
    }

    private struct Chunk {
        let node: SKSpriteNode
        var position: CGPoint
        var velocity: CGVector
    }

    private var flakes: [Flake] = []
    private var chunks: [Chunk] = []
    private var piles: [String: SnowPile] = [:]
    /// Montones ordenados de más alto a más bajo, para comprobar choques.
    private var landingOrder: [SnowPile] = []
    private var menuBarPile: SnowPile?

    private var trackerVersion = -1
    private var menuBarSnowApplied = true
    private var lastUpdate: TimeInterval = 0
    private var clock: TimeInterval = 0
    private var lastPileFrame: TimeInterval = 0
    private var cancellables: Set<AnyCancellable> = []

    /// Se avisa cuando ya no queda nada que animar, para pausar la vista y no gastar batería.
    var onIdle: (() -> Void)?

    init(size: CGSize, screenFrame: CGRect, menuBarHeight: CGFloat) {
        self.screenFrame = screenFrame
        self.menuBarHeight = menuBarHeight
        super.init(size: size)
        backgroundColor = .clear
        scaleMode = .resizeFill

        SnowSettings.shared.sweepRequests
            .sink { [weak self] in MainActor.assumeIsolated { self?.sweep() } }
            .store(in: &cancellables)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no se usa") }

    private var settings: SnowSettings { SnowSettings.shared }

    private var baseFlakeCount: Int {
        let area = size.width * size.height
        return Int(min(max(430 * area / (1512 * 982), 160), 1000))
    }

    // MARK: Bucle

    override func update(_ currentTime: TimeInterval) {
        let dt = CGFloat(lastUpdate == 0 ? 1 / 60 : min(currentTime - lastUpdate, 1 / 20))
        lastUpdate = currentTime
        clock += Double(dt)

        let tracker = WindowTracker.shared
        if tracker.version != trackerVersion || settings.menuBarSnow != menuBarSnowApplied {
            trackerVersion = tracker.version
            menuBarSnowApplied = settings.menuBarSnow
            syncSurfaces()
        }

        spawnFlakesIfNeeded()
        updateFlakes(dt: dt)
        updateChunks(dt: dt)
        updatePiles(dt: dt, time: currentTime)

        if !settings.isSnowing, flakes.isEmpty, chunks.isEmpty, piles.values.allSatisfy(\.isEmpty) {
            onIdle?()
        }
    }

    /// Al reanudar tras una pausa, que el primer fotograma no dé un salto.
    func resume() { lastUpdate = 0 }

    private var currentWind: CGFloat {
        let t = clock
        let gust = sin(t * 0.11) * 0.6 + sin(t * 0.29 + 1) * 0.3 + sin(t * 0.71 + 2) * 0.1
        return CGFloat(settings.wind) * 70 + CGFloat(gust) * 16
    }

    // MARK: Copos

    private func spawnFlakesIfNeeded() {
        guard settings.isSnowing else { return }
        let desired = Int(Double(baseFlakeCount) * settings.intensity)
        guard flakes.count < desired else { return }
        // Pocos por fotograma, para que empiece a nevar poco a poco.
        for _ in 0..<min(6, desired - flakes.count) {
            flakes.append(makeFlake())
        }
    }

    private func makeFlake() -> Flake {
        let depth = CGFloat(pow(Double.random(in: 0...1), 1.4))
        let scale = CGFloat(settings.flakeSize)
        var diameter = (1.6 + depth * 4.6) * scale * CGFloat.random(in: 0.85...1.15)
        let isCrystal = depth > 0.55 && Double.random(in: 0...1) < 0.3
        let node = SKSpriteNode(texture: isCrystal ? SnowTextures.crystal : SnowTextures.soft)
        if isCrystal { diameter *= 2.3 }
        node.size = CGSize(width: diameter, height: diameter)
        node.alpha = 0.45 + depth * 0.5
        node.zPosition = depth
        node.zRotation = .random(in: 0...(2 * .pi))
        addChild(node)

        let start = CGPoint(x: .random(in: -40...(size.width + 40)),
                            y: size.height + diameter + .random(in: 0...40))
        node.position = start
        return Flake(node: node,
                     position: start,
                     fallSpeed: 20 + depth * 46 + .random(in: 0...10),
                     depth: depth,
                     phase: .random(in: 0...(2 * .pi)),
                     swayAmount: 5 + depth * 14,
                     swaySpeed: .random(in: 0.5...1.5),
                     spin: isCrystal ? .random(in: -0.9...0.9) : 0,
                     amount: (1.6 + depth * 4.6) * scale)
    }

    private func updateFlakes(dt: CGFloat) {
        let wind = currentWind
        let width = size.width
        let height = size.height
        let accumulate = settings.accumulate
        let accumulation = CGFloat(settings.accumulationSpeed) * 1.7
        let wantRemoval = !settings.isSnowing || flakes.count > Int(Double(baseFlakeCount) * settings.intensity)

        var mouse: CGPoint?
        if settings.cursorInteraction {
            let global = NSEvent.mouseLocation
            if screenFrame.insetBy(dx: -80, dy: -80).contains(global) {
                mouse = CGPoint(x: global.x - screenFrame.minX, y: global.y - screenFrame.minY)
            }
        }
        let t = CGFloat(clock)

        var i = 0
        while i < flakes.count {
            var flake = flakes[i]
            let previousY = flake.position.y

            var vx = wind * (0.35 + flake.depth * 0.65) + sin(t * flake.swaySpeed + flake.phase) * flake.swayAmount
            var vy = -flake.fallSpeed

            if let mouse {
                let dx = flake.position.x - mouse.x
                let dy = flake.position.y - mouse.y
                let distance = sqrt(dx * dx + dy * dy)
                let radius: CGFloat = 75
                if distance < radius, distance > 0.5 {
                    let push = (1 - distance / radius) * 320
                    vx += dx / distance * push
                    vy += dy / distance * push * 0.7
                }
            }

            flake.position.x += vx * dt
            flake.position.y += vy * dt
            if flake.spin != 0 { flake.node.zRotation += flake.spin * dt }

            // ¿Ha caído sobre algo?
            var landed = false
            if accumulate, previousY > flake.position.y {
                let x = flake.position.x
                if let menu = menuBarPile, previousY >= height, flake.position.y < height,
                   menu.accepts(x), Double.random(in: 0...1) < 0.1 {
                    menu.deposit(at: x, amount: flake.amount * accumulation * 0.6)
                    landed = true
                } else {
                    for pile in landingOrder where pile.style == .resting && pile.accepts(x) {
                        let surface = pile.surfaceY(at: x)
                        if previousY >= surface - 0.5, flake.position.y < surface {
                            pile.deposit(at: x, amount: flake.amount * accumulation)
                            landed = true
                            break
                        }
                    }
                }
            }

            if flake.position.x < -60 { flake.position.x += width + 120 }
            if flake.position.x > width + 60 { flake.position.x -= width + 120 }

            if landed || flake.position.y < -20 {
                if wantRemoval {
                    flake.node.removeFromParent()
                    flakes.swapAt(i, flakes.count - 1)
                    flakes.removeLast()
                    continue
                }
                flake.position = CGPoint(x: .random(in: -40...(width + 40)),
                                         y: height + flake.node.size.height + .random(in: 0...20))
            }

            flake.node.position = flake.position
            flakes[i] = flake
            i += 1
        }
    }

    // MARK: Trozos que se caen cuando una ventana se mueve

    private func dropChunks(_ pieces: [(CGPoint, CGFloat)]) {
        let available = max(0, 500 - chunks.count)
        for (point, diameter) in pieces.prefix(available) {
            let node = SKSpriteNode(texture: SnowTextures.soft)
            node.size = CGSize(width: diameter * 1.6, height: diameter * 1.6)
            node.position = point
            node.zPosition = 0.6
            addChild(node)
            chunks.append(Chunk(node: node, position: point,
                                velocity: CGVector(dx: .random(in: -25...25) + currentWind * 0.3,
                                                   dy: .random(in: 10...70))))
        }
    }

    private func updateChunks(dt: CGFloat) {
        var i = 0
        while i < chunks.count {
            var chunk = chunks[i]
            chunk.velocity.dy -= 520 * dt
            chunk.position.x += chunk.velocity.dx * dt
            chunk.position.y += chunk.velocity.dy * dt
            chunk.node.position = chunk.position
            if chunk.position.y < -20 {
                chunk.node.removeFromParent()
                chunks.swapAt(i, chunks.count - 1)
                chunks.removeLast()
                continue
            }
            chunks[i] = chunk
            i += 1
        }
    }

    // MARK: Montones

    private func updatePiles(dt: CGFloat, time: TimeInterval) {
        // Los montones se recalculan y redibujan a 20 fps: es suficiente y ahorra CPU.
        guard time - lastPileFrame >= 0.05 else { return }
        let elapsed = CGFloat(lastPileFrame == 0 ? 0.05 : min(time - lastPileFrame, 0.25))
        lastPileFrame = time

        let melting = !settings.isSnowing || !settings.accumulate
        for pile in piles.values {
            if melting { pile.melt(by: 0.9 * elapsed) }
            pile.relaxIfNeeded()
            pile.redrawIfNeeded()
        }
    }

    private func sweep() {
        for pile in piles.values {
            dropChunks(pile.shed())
        }
    }

    private struct Surface {
        let style: SnowPile.Style
        let minX: CGFloat
        let maxX: CGFloat
        let baseY: CGFloat
        let cap: CGFloat
        let taper: CGFloat
        let exposed: [ClosedRange<CGFloat>]
    }

    /// Convierte las ventanas, widgets, Dock y barra de menús en bordes donde se posa la nieve.
    private func syncSurfaces() {
        let tracker = WindowTracker.shared
        let width = size.width
        let height = size.height
        let menuBarBottom = height - menuBarHeight
        let local = tracker.windows.map {
            ($0, $0.frame.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY))
        }

        var surfaces: [String: Surface] = [:]

        // Ventanas y widgets, de delante hacia atrás.
        for (index, (window, rect)) in local.enumerated() {
            let top = rect.maxY
            guard top > 1, top < height - 1 else { continue }
            let inset: CGFloat = window.kind == .widget ? 16 : 12
            let minX = max(rect.minX + inset, 0)
            let maxX = min(rect.maxX - inset, width)
            guard maxX - minX > 24 else { continue }

            var exposed = [minX...maxX]
            for (_, front) in local[..<index] where front.minY <= top + 1 && front.maxY >= top - 1 {
                exposed = subtract(front.minX...front.maxX, from: exposed)
            }

            var cap: CGFloat = window.kind == .widget ? 14 : 22
            if menuBarHeight > 0 {
                // Que la nieve de una ventana maximizada no tape los iconos de la barra de menús.
                cap = max(3, min(cap, menuBarBottom - top))
            }
            surfaces["w\(window.id)"] = Surface(style: .resting, minX: minX, maxX: maxX, baseY: top,
                                                cap: cap, taper: window.kind == .widget ? 18 : 26,
                                                exposed: exposed)
        }

        // Dock (solo si hay permiso de Accesibilidad).
        var dockRange: ClosedRange<CGFloat>?
        if let dock = tracker.dockFrame, dock.intersects(screenFrame) {
            let rect = dock.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
            let minX = max(rect.minX + 8, 0)
            let maxX = min(rect.maxX - 8, width)
            if maxX - minX > 24 {
                dockRange = rect.minX...rect.maxX
                surfaces["dock"] = Surface(style: .resting, minX: minX, maxX: maxX, baseY: rect.maxY,
                                           cap: 14, taper: 20, exposed: [minX...maxX])
            }
        }

        // Suelo: el borde inferior de la pantalla.
        var groundExposed = [CGFloat(0)...width]
        for (_, rect) in local where rect.minY <= 1 && rect.maxY > 0 {
            groundExposed = subtract(rect.minX...rect.maxX, from: groundExposed)
        }
        if let dockRange { groundExposed = subtract(dockRange, from: groundExposed) }
        surfaces["ground"] = Surface(style: .resting, minX: 0, maxX: width, baseY: 0,
                                     cap: 16, taper: 6, exposed: groundExposed)

        // Barra de menús: escarcha colgando del borde superior (si al quitarla había nieve, se cae).
        if menuBarHeight > 0, settings.menuBarSnow {
            surfaces["menubar"] = Surface(style: .hanging, minX: 0, maxX: width, baseY: height,
                                          cap: 6, taper: 4, exposed: [CGFloat(0)...width])
        }

        // Los montones cuyo borde se ha movido o desaparecido se caen.
        for (id, pile) in piles {
            if let surface = surfaces[id],
               pile.sameGeometry(minX: surface.minX, maxX: surface.maxX, baseY: surface.baseY) {
                pile.cap = surface.cap
                pile.exposed = surface.exposed
            } else {
                dropChunks(pile.shed())
                pile.node.removeFromParent()
                piles[id] = nil
            }
        }
        for (id, surface) in surfaces where piles[id] == nil {
            let pile = SnowPile(style: surface.style, minX: surface.minX, maxX: surface.maxX,
                                baseY: surface.baseY, cap: surface.cap, taper: surface.taper)
            pile.exposed = surface.exposed
            addChild(pile.node)
            piles[id] = pile
        }

        landingOrder = piles.values.sorted { $0.baseY > $1.baseY }
        menuBarPile = piles["menubar"]
    }

    private func subtract(_ cut: ClosedRange<CGFloat>, from intervals: [ClosedRange<CGFloat>]) -> [ClosedRange<CGFloat>] {
        var result: [ClosedRange<CGFloat>] = []
        for interval in intervals {
            guard cut.overlaps(interval) else { result.append(interval); continue }
            if interval.lowerBound < cut.lowerBound { result.append(interval.lowerBound...cut.lowerBound) }
            if interval.upperBound > cut.upperBound { result.append(cut.upperBound...interval.upperBound) }
        }
        return result
    }
}
