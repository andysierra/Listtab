// Genera resources/AppIcon.icns: uso `swift tools/make-icon.swift`
import AppKit

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: a)
}

func draw(in ctx: CGRect) {
    // Cuerpo "squircle" de macOS: 824/1024 con margen para la sombra.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let shape = NSBezierPath(roundedRect: body, xRadius: 186, yRadius: 186)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
    shadow.shadowOffset = NSSize(width: 0, height: -14)
    shadow.shadowBlurRadius = 28
    shadow.set()
    rgb(0x1a1b26).setFill(); shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSGradient(colors: [rgb(0x2a2f4a), rgb(0x16161e)])!.draw(in: body, angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Lista: 4 filas, la segunda seleccionada.
    let rowH: CGFloat = 112, gap: CGFloat = 34
    let total = rowH * 4 + gap * 3
    var y = body.midY + total / 2 - rowH
    let x0 = body.minX + 96, w = body.width - 192
    let widths: [CGFloat] = [0.62, 0.78, 0.5, 0.7]
    for i in 0..<4 {
        let row = NSRect(x: x0, y: y, width: w, height: rowH)
        let selected = i == 1
        if selected {
            NSGraphicsContext.saveGraphicsState()
            let g = NSShadow(); g.shadowColor = rgb(0x7aa2f7, 0.55); g.shadowBlurRadius = 30; g.set()
            rgb(0x7aa2f7).setFill()
            NSBezierPath(roundedRect: row, xRadius: 36, yRadius: 36).fill()
            NSGraphicsContext.restoreGraphicsState()
        }
        // "icono" de la fila + barra de titulo
        let dot = NSRect(x: row.minX + 28, y: row.midY - 28, width: 56, height: 56)
        (selected ? NSColor.white : rgb(0xbb9af7)).setFill()
        NSBezierPath(roundedRect: dot, xRadius: 16, yRadius: 16).fill()
        let bar = NSRect(x: dot.maxX + 28, y: row.midY - 16, width: (w - 150) * widths[i], height: 32)
        (selected ? NSColor.white : rgb(0xc0caf5, 0.8)).setFill()
        NSBezierPath(roundedRect: bar, xRadius: 16, yRadius: 16).fill()
        y -= rowH + gap
    }
}

func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    let t = NSAffineTransform(); t.scale(by: CGFloat(size) / 1024); t.concat()
    draw(in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let dir = "build/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: dir)
try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! png(size: base).write(to: URL(fileURLWithPath: "\(dir)/icon_\(base)x\(base).png"))
    try! png(size: base * 2).write(to: URL(fileURLWithPath: "\(dir)/icon_\(base)x\(base)@2x.png"))
}
print("iconset en \(dir)")
