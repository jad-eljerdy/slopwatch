import SwiftUI

struct WatchMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(center: CGPoint(x: 12, y: 13), radius: 8, startAngle: .degrees(-54), endAngle: .degrees(258), clockwise: false)
        p.move(to: CGPoint(x: 12, y: 13))
        p.addLine(to: CGPoint(x: 16.8, y: 7.6))
        p.move(to: CGPoint(x: 9.8, y: 1.7))
        p.addLine(to: CGPoint(x: 14.2, y: 1.7))
        return p.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}

@MainActor
func menuBarImage() -> NSImage {
    let image = NSImage(size: NSSize(width: 20, height: 20), flipped: true) { rect in
        let path = NSBezierPath(cgPath: WatchMark().path(in: rect).cgPath)
        NSColor.black.setStroke()
        path.lineWidth = 1.8
        path.lineCapStyle = .round
        path.stroke()
        return true
    }
    image.isTemplate = true
    image.accessibilityDescription = "Slopwatch"
    return image
}
