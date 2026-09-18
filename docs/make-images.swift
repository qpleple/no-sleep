// Renders docs/logo.png and docs/states.png. Usage: swift docs/make-images.swift
import Cocoa

func png(_ image: NSImage, to path: String) {
    let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

func cup(_ color: NSColor, pointSize: CGFloat) -> NSImage {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
        .applying(.init(paletteColors: [color]))
    return NSImage(systemSymbolName: "cup.and.saucer.fill", accessibilityDescription: nil)!
        .withSymbolConfiguration(config)!
}

// One dark menu-bar strip per state, with the cup and a clock, 2x for Retina.
let states: [(String, NSColor)] = [("Off", .white), ("Awake", .systemYellow), ("Insomniac", .systemRed)]
let scale: CGFloat = 2
let w: CGFloat = 420, rowH: CGFloat = 48, gap: CGFloat = 14
let total = NSSize(width: w * scale, height: (rowH * CGFloat(states.count) + gap * CGFloat(states.count - 1)) * scale)

let strip = NSImage(size: total, flipped: false) { _ in
    NSGraphicsContext.current!.cgContext.scaleBy(x: scale, y: scale)
    let labelFont = NSFont.systemFont(ofSize: 13, weight: .medium)
    let clockFont = NSFont.systemFont(ofSize: 13.5, weight: .regular)
    for (i, (name, color)) in states.enumerated() {
        let y = (rowH + gap) * CGFloat(states.count - 1 - i)
        let rect = NSRect(x: 0, y: y, width: w, height: rowH)
        NSColor(calibratedWhite: 0.11, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10).fill()

        // state label on the left
        (name as NSString).draw(at: NSPoint(x: 16, y: y + 15),
                                withAttributes: [.font: labelFont, .foregroundColor: NSColor(calibratedWhite: 0.6, alpha: 1)])
        // clock on the right
        let clock = "Thu 18 Sep  16:57" as NSString
        let cs = clock.size(withAttributes: [.font: clockFont])
        clock.draw(at: NSPoint(x: w - 16 - cs.width, y: y + (rowH - cs.height) / 2),
                   withAttributes: [.font: clockFont, .foregroundColor: NSColor.white])
        // the cup, just left of the clock
        let img = cup(color, pointSize: 15)
        let s = img.size
        img.draw(in: NSRect(x: w - 16 - cs.width - 22 - s.width, y: y + (rowH - s.height) / 2, width: s.width, height: s.height))
    }
    return true
}
png(strip, to: "docs/states.png")

// Logo: reuse the app icon render at 256 px.
let iconPNG = NSImage(contentsOfFile: ".build/AppIcon.iconset/icon_128x128@2x.png")!
png(iconPNG, to: "docs/logo.png")
