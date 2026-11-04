import AppKit
import SpriteKit

/// Texturas generadas en código: un copo suave (la mayoría) y un cristal de seis brazos (los grandes).
@MainActor
enum SnowTextures {
    static let soft: SKTexture = {
        let size = CGSize(width: 32, height: 32)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let colors = [
                CGColor(red: 1, green: 1, blue: 1, alpha: 1),
                CGColor(red: 1, green: 1, blue: 1, alpha: 0.85),
                CGColor(red: 0.95, green: 0.97, blue: 1, alpha: 0),
            ] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                      locations: [0, 0.45, 1])!
            let center = CGPoint(x: rect.midX, y: rect.midY)
            ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                   endCenter: center, endRadius: rect.width / 2, options: [])
            return true
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }()

    /// Relleno de los montones: blanco arriba, azul hielo muy suave abajo.
    static let pileShading: SKTexture = {
        let size = CGSize(width: 4, height: 64)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let colors = [
                CGColor(red: 0.80, green: 0.86, blue: 0.95, alpha: 1),
                CGColor(red: 0.93, green: 0.96, blue: 1.0, alpha: 1),
                CGColor(red: 1, green: 1, blue: 1, alpha: 1),
            ] as CFArray
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                      locations: [0, 0.45, 1])!
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: rect.minY),
                                   end: CGPoint(x: 0, y: rect.maxY), options: [])
            return true
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }()

    static let crystal: SKTexture = {
        let size = CGSize(width: 64, height: 64)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius = rect.width * 0.44

            ctx.setLineCap(.round)
            ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            ctx.setShadow(offset: .zero, blur: 3, color: CGColor(red: 0.85, green: 0.92, blue: 1, alpha: 0.9))

            for arm in 0..<6 {
                let angle = CGFloat(arm) * .pi / 3 + .pi / 2
                let dir = CGPoint(x: cos(angle), y: sin(angle))
                let tip = CGPoint(x: center.x + dir.x * radius, y: center.y + dir.y * radius)

                ctx.setLineWidth(3.2)
                ctx.move(to: center)
                ctx.addLine(to: tip)
                ctx.strokePath()

                // Ramitas en forma de V a lo largo de cada brazo.
                ctx.setLineWidth(2.4)
                for (along, length) in [(0.45, 0.30), (0.72, 0.22)] as [(CGFloat, CGFloat)] {
                    let base = CGPoint(x: center.x + dir.x * radius * along, y: center.y + dir.y * radius * along)
                    for side in [-1.0, 1.0] as [CGFloat] {
                        let branchAngle = angle + side * .pi / 4
                        let end = CGPoint(x: base.x + cos(branchAngle) * radius * length,
                                          y: base.y + sin(branchAngle) * radius * length)
                        ctx.move(to: base)
                        ctx.addLine(to: end)
                        ctx.strokePath()
                    }
                }
            }
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            ctx.fillEllipse(in: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8))
            return true
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }()
}
