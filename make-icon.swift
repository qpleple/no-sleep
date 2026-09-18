// Renders AppIcon.icns: macOS-style rounded square with the coffee cup symbol.
// Usage: swift make-icon.swift <output-dir>
import Cocoa

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
    // Apple's icon grid: the squircle occupies ~82% of the canvas.
    let inset = size * 0.09
    let squircle = NSBezierPath(roundedRect: rect.insetBy(dx: inset, dy: inset),
                                xRadius: size * 0.185, yRadius: size * 0.185)
    let gradient = NSGradient(colors: [NSColor(calibratedRed: 0.16, green: 0.17, blue: 0.22, alpha: 1),
                                       NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.08, alpha: 1)])!
    gradient.draw(in: squircle, angle: -90)

    let config = NSImage.SymbolConfiguration(pointSize: size * 0.5, weight: .medium)
        .applying(.init(paletteColors: [NSColor.systemYellow]))
    guard let symbol = NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) else { return false }
    let s = symbol.size
    let scale = (size * 0.56) / max(s.width, s.height)
    let drawSize = NSSize(width: s.width * scale, height: s.height * scale)
    let origin = NSPoint(x: (size - drawSize.width) / 2, y: (size - drawSize.height) / 2)
    symbol.draw(in: NSRect(origin: origin, size: drawSize))
    return true
}

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { fatalError("render failed") }
try! png.write(to: URL(fileURLWithPath: outDir).appendingPathComponent("icon_1024.png"))
