// Genera Resources/AppIcon.icns: noche azul, un copo grande y nieve amontonada abajo.
import AppKit

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    let inset = s * 0.1
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let shape = CGPath(roundedRect: rect, cornerWidth: rect.width * 0.225, cornerHeight: rect.width * 0.225, transform: nil)
    ctx.addPath(shape); ctx.clip()

    let sky = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                         colors: [CGColor(red: 0.05, green: 0.10, blue: 0.28, alpha: 1),
                                  CGColor(red: 0.16, green: 0.33, blue: 0.62, alpha: 1)] as CFArray,
                         locations: [0, 1])!
    ctx.drawLinearGradient(sky, start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: 0, y: rect.minY), options: [])

    // Copos pequeños de fondo.
    var rng = SystemRandomNumberGenerator()
    srand48(7)
    for _ in 0..<38 {
        let r = rect.width * CGFloat(0.006 + drand48() * 0.012)
        let p = CGPoint(x: rect.minX + CGFloat(drand48()) * rect.width, y: rect.minY + rect.height * CGFloat(0.25 + drand48() * 0.75))
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: CGFloat(0.4 + drand48() * 0.5)))
        ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
    }
    _ = rng.next()

    // Copo grande.
    let c = CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.08)
    let R = rect.width * 0.27
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.setLineCap(.round)
    ctx.setShadow(offset: .zero, blur: s * 0.02, color: CGColor(red: 0.7, green: 0.85, blue: 1, alpha: 0.9))
    for arm in 0..<6 {
        let a = CGFloat(arm) * .pi / 3 + .pi / 2
        let d = CGPoint(x: cos(a), y: sin(a))
        ctx.setLineWidth(rect.width * 0.035)
        ctx.move(to: c); ctx.addLine(to: CGPoint(x: c.x + d.x * R, y: c.y + d.y * R)); ctx.strokePath()
        ctx.setLineWidth(rect.width * 0.026)
        for (along, len) in [(0.5, 0.3), (0.76, 0.2)] as [(CGFloat, CGFloat)] {
            let b = CGPoint(x: c.x + d.x * R * along, y: c.y + d.y * R * along)
            for side in [-1.0, 1.0] as [CGFloat] {
                let ba = a + side * .pi / 4
                ctx.move(to: b); ctx.addLine(to: CGPoint(x: b.x + cos(ba) * R * len, y: b.y + sin(ba) * R * len)); ctx.strokePath()
            }
        }
    }
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    // Nieve amontonada.
    let snow = CGMutablePath()
    snow.move(to: CGPoint(x: rect.minX, y: rect.minY))
    snow.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.17))
    snow.addCurve(to: CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.14),
                  control1: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.minY + rect.height * 0.26),
                  control2: CGPoint(x: rect.midX - rect.width * 0.15, y: rect.minY + rect.height * 0.12))
    snow.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.2),
                  control1: CGPoint(x: rect.midX + rect.width * 0.18, y: rect.minY + rect.height * 0.17),
                  control2: CGPoint(x: rect.maxX - rect.width * 0.15, y: rect.minY + rect.height * 0.27))
    snow.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
    snow.closeSubpath()
    ctx.addPath(snow)
    ctx.setFillColor(CGColor(red: 0.62, green: 0.72, blue: 0.88, alpha: 1))
    ctx.fillPath()
    ctx.translateBy(x: 0, y: -rect.height * 0.018)
    ctx.addPath(snow)
    ctx.setFillColor(CGColor(red: 0.98, green: 0.99, blue: 1, alpha: 1))
    ctx.fillPath()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let out = CommandLine.arguments[1]
let iconset = URL(fileURLWithPath: out).deletingLastPathComponent().appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", out]
try! task.run(); task.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
