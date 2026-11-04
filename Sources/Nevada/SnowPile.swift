import AppKit
import SpriteKit

/// Un montón de nieve sobre un borde horizontal (el techo de una ventana, el suelo, el Dock…)
/// guardado como un mapa de alturas en columnas de 3 pt. Coordenadas locales de la escena.
@MainActor
final class SnowPile {
    enum Style {
        /// La nieve crece hacia arriba desde el borde (ventanas, widgets, Dock, suelo).
        case resting
        /// La nieve cuelga hacia abajo desde el borde superior de la pantalla (barra de menús).
        case hanging
    }

    static let bucket: CGFloat = 3

    let style: Style
    let minX: CGFloat
    let maxX: CGFloat
    let baseY: CGFloat
    /// Altura máxima en el centro del montón.
    var cap: CGFloat { didSet { if cap < oldValue { clampToLimits() } } }
    /// Tramos del borde que no tapa ninguna ventana de delante. Solo ahí se posa y se dibuja la nieve.
    var exposed: [ClosedRange<CGFloat>] = [] { didSet { if exposed != oldValue { needsRedraw = true } } }

    private(set) var heights: [CGFloat]
    private(set) var needsRedraw = true
    private var needsRelax = false
    /// Distancia desde los extremos en la que el montón se va afinando (los bordes redondeados de la ventana).
    private let taper: CGFloat
    private let profile: [CGFloat]

    let node = SKShapeNode()
    private let shadow = SKShapeNode()

    init(style: Style, minX: CGFloat, maxX: CGFloat, baseY: CGFloat, cap: CGFloat, taper: CGFloat = 22) {
        self.style = style
        self.minX = minX
        self.maxX = maxX
        self.baseY = baseY
        self.cap = cap
        self.taper = taper
        let count = max(2, Int(((maxX - minX) / Self.bucket).rounded(.up)) + 1)
        heights = Array(repeating: 0, count: count)
        profile = Self.makeProfile(count: count)

        // Degradado vertical: blanco arriba y un poco azulado abajo, para que tenga volumen.
        node.fillTexture = SnowTextures.pileShading
        node.fillColor = .white
        node.alpha = 0.98
        node.strokeColor = .clear
        node.lineWidth = 0
        node.isAntialiased = true
        node.zPosition = 0.5

        shadow.fillColor = NSColor(calibratedRed: 0.55, green: 0.65, blue: 0.82, alpha: 0.38)
        shadow.strokeColor = .clear
        shadow.lineWidth = 0
        shadow.isAntialiased = true
        shadow.position = style == .resting ? CGPoint(x: 0.8, y: -1.4) : CGPoint(x: 0.6, y: -1.6)
        shadow.zPosition = -0.01
        node.addChild(shadow)
    }

    var isEmpty: Bool { !heights.contains { $0 > 0.05 } }

    func sameGeometry(minX: CGFloat, maxX: CGFloat, baseY: CGFloat) -> Bool {
        abs(self.minX - minX) < 0.5 && abs(self.maxX - maxX) < 0.5 && abs(self.baseY - baseY) < 0.5
    }

    // MARK: Consultas

    private func index(_ x: CGFloat) -> Int {
        min(max(Int(((x - minX) / Self.bucket).rounded()), 0), heights.count - 1)
    }

    private func xAt(_ i: Int) -> CGFloat { min(minX + CGFloat(i) * Self.bucket, maxX) }

    /// Altura máxima de cada columna. Cuando el montón se llena adopta esta forma:
    /// lomas irregulares (el perfil de ruido) y extremos redondeados como un cojín, nunca una losa plana.
    private func limit(_ i: Int) -> CGFloat {
        let x = xAt(i)
        let distance = min(x - minX, maxX - x)
        let t = min(1, max(0, distance / taper))
        let rounded = (1 - (1 - t) * (1 - t)).squareRoot()
        return cap * profile[i] * max(0.06, rounded)
    }

    /// Ruido suave con dos escalas: lomas de ~120 pt y bultos de ~38 pt. Valores entre 0.45 y 1.
    private static func makeProfile(count: Int) -> [CGFloat] {
        func octave(_ wavelength: CGFloat) -> [CGFloat] {
            let step = wavelength / bucket
            let knots = (0..<(Int(CGFloat(count) / step) + 3)).map { _ in CGFloat.random(in: 0...1) }
            return (0..<count).map { i in
                let p = CGFloat(i) / step
                let k = Int(p)
                let s = (1 - cos((p - CGFloat(k)) * .pi)) / 2
                return knots[k] * (1 - s) + knots[k + 1] * s
            }
        }
        let hills = octave(115)
        let bumps = octave(40)
        let grain = octave(12)
        var result: [CGFloat] = []
        result.reserveCapacity(count)
        for i in 0..<count {
            let value: CGFloat = 0.22 + 0.6 * hills[i] + 0.14 * bumps[i] + 0.04 * grain[i]
            result.append(value)
        }
        return result
    }

    func height(at x: CGFloat) -> CGFloat {
        let position = (x - minX) / Self.bucket
        let i = min(max(Int(position), 0), heights.count - 1)
        let j = min(i + 1, heights.count - 1)
        let f = min(max(position - CGFloat(i), 0), 1)
        return heights[i] * (1 - f) + heights[j] * f
    }

    /// ¿Puede posarse un copo en esta x?
    func accepts(_ x: CGFloat) -> Bool {
        guard x >= minX, x <= maxX else { return false }
        return exposed.contains { $0.contains(x) }
    }

    /// Altura de la superficie de nieve donde chocan los copos que caen.
    func surfaceY(at x: CGFloat) -> CGFloat {
        style == .resting ? baseY + height(at: x) : baseY - height(at: x)
    }

    // MARK: Cambios

    private static let kernel: [(Int, CGFloat)] = [(-3, 0.05), (-2, 0.12), (-1, 0.2), (0, 0.26), (1, 0.2), (2, 0.12), (3, 0.05)]

    func deposit(at x: CGFloat, amount: CGFloat) {
        let center = index(x)
        for (offset, weight) in Self.kernel {
            let j = center + offset
            guard j >= 0, j < heights.count else { continue }
            heights[j] = min(limit(j), heights[j] + amount * weight)
        }
        needsRedraw = true
        needsRelax = true
    }

    /// La nieve se desliza si una columna queda mucho más alta que su vecina.
    func relaxIfNeeded() {
        guard needsRelax else { return }
        needsRelax = false
        // Pendiente máxima ~38°: lomas suaves en vez de picos.
        let maxStep = Self.bucket * 0.78
        for _ in 0..<2 {
            for i in 0..<(heights.count - 1) {
                let diff = heights[i] - heights[i + 1]
                guard abs(diff) > maxStep else { continue }
                // Solo se mueve la nieve que cabe en la columna vecina: así no se pierde
                // por los extremos y los bordes quedan redondeados en vez de en rampa.
                let (high, low) = diff > 0 ? (i, i + 1) : (i + 1, i)
                let move = min((abs(diff) - maxStep) * 0.3, limit(low) - heights[low])
                guard move > 0 else { continue }
                heights[high] -= move
                heights[low] += move
            }
        }
    }

    func melt(by amount: CGFloat) {
        guard !isEmpty else { return }
        for i in heights.indices where heights[i] > 0 {
            heights[i] = max(0, heights[i] - amount * (0.6 + 0.4 * heights[i] / max(cap, 1)))
        }
        needsRedraw = true
    }

    /// Vacía el montón y devuelve trozos de nieve (posición, tamaño) para que caigan.
    func shed() -> [(CGPoint, CGFloat)] {
        var chunks: [(CGPoint, CGFloat)] = []
        var i = 0
        while i < heights.count {
            let h = heights[i]
            let x = xAt(i)
            if h > 0.8, accepts(x) {
                let y = style == .resting ? baseY + h * 0.5 : baseY - h * 0.5
                chunks.append((CGPoint(x: x, y: y), min(max(h * 0.9, 2), 8)))
            }
            i += 2
        }
        heights = Array(repeating: 0, count: heights.count)
        needsRedraw = true
        return chunks
    }

    private func clampToLimits() {
        for i in heights.indices { heights[i] = min(heights[i], limit(i)) }
        needsRedraw = true
    }

    // MARK: Dibujo

    func redrawIfNeeded() {
        guard needsRedraw else { return }
        needsRedraw = false

        let path = CGMutablePath()
        let sign: CGFloat = style == .resting ? 1 : -1
        // Un poco por debajo (o por encima) del borde para que no quede una rendija.
        let edge = baseY - sign * 1.5

        // Solo se dibujan los tramos donde de verdad hay nieve: un montón recién vacío
        // (por ejemplo, al mover la ventana) no debe dejar ninguna línea en el borde.
        let threshold: CGFloat = 0.3
        for interval in exposed {
            let a = max(interval.lowerBound, minX)
            let b = min(interval.upperBound, maxX)
            guard b - a > 2 else { continue }

            let first = index(a), last = index(b)
            var i = first
            while i <= last {
                guard heights[i] > threshold else { i += 1; continue }
                var end = i
                while end + 1 <= last, heights[end + 1] > threshold { end += 1 }

                // Un cubo más a cada lado para que el montón baje suave hasta el borde.
                let startX = max(a, xAt(max(i - 1, first)))
                let endX = min(b, xAt(min(end + 1, last)))
                i = end + 1
                guard endX - startX > 1 else { continue }

                var points: [CGPoint] = []
                var x = startX
                while x < endX {
                    points.append(CGPoint(x: x, y: baseY + sign * height(at: x)))
                    x += Self.bucket
                }
                points.append(CGPoint(x: endX, y: baseY + sign * height(at: endX)))

                path.move(to: CGPoint(x: startX, y: edge))
                path.addLine(to: points[0])
                for k in 1..<points.count {
                    let previous = points[k - 1]
                    let mid = CGPoint(x: (previous.x + points[k].x) / 2, y: (previous.y + points[k].y) / 2)
                    path.addQuadCurve(to: mid, control: previous)
                }
                path.addLine(to: points[points.count - 1])
                path.addLine(to: CGPoint(x: endX, y: edge))
                path.closeSubpath()
            }
        }

        node.path = path
        shadow.path = path
    }
}
