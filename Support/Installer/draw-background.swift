import AppKit
import CoreText
import ImageIO
import UniformTypeIdentifiers

// Coordinates are Finder points, measured from the top left of its content area.
let width = 660
let height = 420
let version = CommandLine.arguments[1]
let directory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ rgb: Int, alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(rgb >> 16) / 255, green: CGFloat((rgb >> 8) & 255) / 255,
            blue: CGFloat(rgb & 255) / 255, alpha: alpha)
}

func draw(in c: CGContext) {
    func line(_ from: CGPoint, _ to: CGPoint, _ ink: CGColor, width: CGFloat = 1) {
        c.setStrokeColor(ink)
        c.setLineWidth(width)
        c.move(to: from)
        c.addLine(to: to)
        c.strokePath()
    }

    func text(_ string: String, at x: CGFloat, baseline y: CGFloat, font: NSFont, ink: CGColor, tracking: CGFloat = 0) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: NSColor(cgColor: ink)!, .kern: tracking
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes))
        c.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        c.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, c)
    }

    let navy = color(0x172c80)
    let white = color(0xfffcf1)
    let blue = color(0x2a47c1)
    let paper = color(0xf5f4eb)
    let light = color(0xaebbf4)
    c.setFillColor(paper)
    c.fill(CGRect(x: 0, y: 0, width: width, height: height))

    c.saveGState()
    c.clip(to: CGRect(x: 0, y: 0, width: width, height: 176))
    let gradient = CGGradient(colorsSpace: space, colors: [navy, blue] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 640, y: 170), options: [.drawsAfterEndLocation])
    let grid = color(0xdce7ff, alpha: 0.09)
    for x in stride(from: 0, through: width, by: 20) {
        line(CGPoint(x: x, y: 0), CGPoint(x: x, y: 176), grid, width: 0.6)
    }
    for y in stride(from: 0, through: 176, by: 20) {
        line(CGPoint(x: 0, y: y), CGPoint(x: width, y: y), grid, width: 0.6)
    }
    // A cropped stopwatch dial shares its mint hand and warm accents with the app icon.
    let hub = CGPoint(x: 566, y: 122)
    func point(_ radius: CGFloat, _ angle: CGFloat) -> CGPoint {
        CGPoint(x: hub.x + radius * cos(angle), y: hub.y + radius * sin(angle))
    }
    for radius: CGFloat in [86, 108, 112, 118] {
        c.setStrokeColor(color(0xc7d5fa, alpha: 0.6))
        c.setLineWidth(0.8)
        c.strokeEllipse(in: CGRect(x: hub.x - radius, y: hub.y - radius, width: radius * 2, height: radius * 2))
    }
    for tick in 0..<60 {
        let angle = CGFloat(tick) * .pi / 30
        let major = tick.isMultiple(of: 5)
        line(point(major ? 89 : 98, angle), point(105, angle), light, width: major ? 2 : 0.85)
    }
    c.setLineCap(.round)
    line(point(16, .pi * 0.72), point(81, -.pi * 0.28), color(0xa3ead7), width: 5)
    c.setFillColor(white)
    c.fillEllipse(in: CGRect(x: hub.x - 4, y: hub.y - 4, width: 8, height: 8))
    let mono = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
    text("macOS  /  v" + version, at: 36, baseline: 42, font: mono, ink: color(0xc5dae6), tracking: 1)
    text("Slopwatch", at: 32, baseline: 124, font: .systemFont(ofSize: 72, weight: .semibold), ink: white, tracking: -4)
    text("Drag Slopwatch into Applications.", at: 36, baseline: 154,
         font: .systemFont(ofSize: 17, weight: .medium), ink: white)
    c.restoreGState()

    c.setLineCap(.round)
    let arrowY: CGFloat = 251
    line(CGPoint(x: 279, y: arrowY), CGPoint(x: 380, y: arrowY), blue, width: 3)
    line(CGPoint(x: 368, y: arrowY - 11), CGPoint(x: 380, y: arrowY), blue, width: 3)
    line(CGPoint(x: 368, y: arrowY + 11), CGPoint(x: 380, y: arrowY), blue, width: 3)
}

for scale in [1, 2] {
    let c = CGContext(data: nil, width: width * scale, height: height * scale,
                      bitsPerComponent: 8, bytesPerRow: 0, space: space,
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    c.translateBy(x: 0, y: CGFloat(height * scale))
    c.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
    draw(in: c)
    let url = directory.appendingPathComponent(scale == 1 ? "background.png" : "background@2x.png")
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, c.makeImage()!, nil)
    guard CGImageDestinationFinalize(destination) else { exit(1) }
}
