import Foundation

enum PopoverPlacement {
    static func availableFrame(display: CGRect, visible: CGRect, menuHeight: CGFloat) -> CGRect {
        let top = min(visible.maxY, display.maxY - menuHeight)
        return CGRect(x: visible.minX, y: visible.minY, width: visible.width, height: max(0, top - visible.minY))
    }

    static func origin(for size: CGSize, centeredAt x: CGFloat, in available: CGRect) -> CGPoint {
        let left = min(x - size.width / 2, available.maxX - size.width)
        return CGPoint(x: max(available.minX, left), y: max(available.minY, available.maxY - size.height))
    }
}
