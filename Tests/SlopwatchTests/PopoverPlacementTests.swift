import Foundation
import Testing
@testable import Slopwatch

@Test func panelStaysBelowTheMenuBarAfterResizing() {
    let display = CGRect(x: 0, y: 0, width: 1728, height: 1117)
    let visible = CGRect(x: 0, y: 78, width: 1728, height: 1006)
    let area = PopoverPlacement.availableFrame(display: display, visible: visible, menuHeight: 32)
    for height: CGFloat in [260, 519, 680] {
        let size = CGSize(width: 406, height: height)
        let frame = CGRect(origin: PopoverPlacement.origin(for: size, centeredAt: 1097, in: area), size: size)
        #expect(visible.contains(frame))
        #expect(frame.maxY == 1084)
    }
}

@Test func secondaryDisplayReservesHiddenMenuAndClampsBothEdges() {
    let display = CGRect(x: -1440, y: 520, width: 1440, height: 900)
    let area = PopoverPlacement.availableFrame(display: display, visible: display, menuHeight: 24)
    let size = CGSize(width: 405, height: 520)
    for x in [display.minX, display.maxX] {
        let frame = CGRect(origin: PopoverPlacement.origin(for: size, centeredAt: x, in: area), size: size)
        #expect(area.contains(frame))
        #expect(frame.maxY == display.maxY - 24)
    }
}
