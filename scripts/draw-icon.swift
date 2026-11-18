import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size, flipped: true) { _ in
    let tile = NSBezierPath(roundedRect: NSRect(x: 88, y: 88, width: 848, height: 848), xRadius: 188, yRadius: 188)
    let top = NSColor(srgbRed: 0.17, green: 0.23, blue: 0.24, alpha: 1)
    let bottom = NSColor(srgbRed: 0.045, green: 0.065, blue: 0.08, alpha: 1)
    NSGradient(starting: top, ending: bottom)?.draw(in: tile, angle: 65)
    let center = CGPoint(x: 512, y: 535)
    let ring = NSBezierPath()
    ring.appendArc(withCenter: center, radius: 237, startAngle: -53, endAngle: 258)
    ring.lineWidth = 43
    ring.lineCapStyle = .round
    NSColor(srgbRed: 0.48, green: 0.86, blue: 0.76, alpha: 1).setStroke()
    ring.stroke()
    let hand = NSBezierPath()
    hand.move(to: center)
    hand.line(to: CGPoint(x: 656, y: 364))
    hand.move(to: CGPoint(x: 460, y: 204))
    hand.line(to: CGPoint(x: 564, y: 204))
    hand.lineWidth = 44
    hand.lineCapStyle = .round
    NSColor(srgbRed: 0.99, green: 0.84, blue: 0.66, alpha: 1).setStroke()
    hand.stroke()
    return true
}
guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
try data.write(to: URL(filePath: CommandLine.arguments[1]))
