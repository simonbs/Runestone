#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class ObscuredContentGeometryTests: XCTestCase {
    func testFindRevealsTheFinalLineAboveTheStatusAccessory() throws {
        let text = String(repeating: "line\n", count: 60) + "last"
        let (_, scroll, view) = makeView(text)
        let range = (text as NSString).range(of: "last")
        view.scrollTextFinderRangeToVisible(range)
        view.updateViewport()
        let rects = view.textFinderRects(for: range)
        XCTAssertFalse(rects.isEmpty)
        let visible = view.unobscuredContentViewport(scroll.contentView.bounds)
        XCTAssertTrue(rects.allSatisfy { $0.maxY <= visible.maxY + 0.01 && $0.minY >= visible.minY - 0.01 },
                      "rects=\(rects), visible=\(visible), clip=\(scroll.contentView.bounds), insets=\(scroll.contentInsets)")
        XCTAssertEqual(view.visibleLayout?.viewport, scroll.contentView.bounds, "Backdrop layout still extends behind the accessory")
    }

    func testCaretAndAccessibilityRespectOcclusionWhileBackdropStillDraws() throws {
        let (_, scroll, view) = makeView(String(repeating: "line\n", count: 60))
        let visible = view.unobscuredContentViewport(scroll.contentView.bounds)
        let line = try XCTUnwrap(view.visibleLayout?.lines.first { item in
            item.placements.contains { $0.frame.maxY > visible.maxY && $0.frame.maxY <= scroll.contentView.bounds.maxY }
        })
        let range = NSRange(location: line.line.location, length: 1)
        XCTAssertFalse(view.textFinderRects(for: range).isEmpty)
        XCTAssertNil(AccessibilityTextGeometry.frame(for: range, in: view))
        let target = InputCaretTarget(location: range.location, affinity: nil)
        XCTAssertNotNil(view.verticalMovementReveal(for: target, from: scroll.contentView.bounds))
        XCTAssertEqual(view.revealOffscreenMovementCaret(target, clock: { ProcessInfo.processInfo.systemUptime }, isCurrent: { true }), .progressed)
        let after = view.unobscuredContentViewport(scroll.contentView.bounds)
        let caret = try XCTUnwrap(InputCaretAffinityGeometry.documentRect(for: target, in: view))
        XCTAssertLessThanOrEqual(caret.maxY, after.maxY + 0.01)
    }

    func testShortDocumentDoesNotGainAnExtraAccessoryHeightOfScrolling() {
        let (_, scroll, view) = makeView("short")
        XCTAssertEqual(view.frame.height, view.unobscuredContentViewport(scroll.contentView.bounds).height, accuracy: 0.01)
        var far = scroll.contentView.bounds
        far.origin.y = 10000
        let end = scroll.contentView.constrainBoundsRect(far)
        XCTAssertEqual(end.minY, -scroll.contentInsets.top, accuracy: 0.01)
        scroll.contentInsets.bottom = 0
        view.updateViewport()
        XCTAssertEqual(view.frame.height, scroll.contentView.bounds.height - scroll.contentInsets.top, accuracy: 0.01)
    }

    private func makeView(_ text: String) -> (NSWindow, NSScrollView, ReadOnlyDocumentView) {
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 220, height: 120),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let scroll = NSScrollView(frame: window.contentView!.bounds)
        scroll.automaticallyAdjustsContentInsets = false
        scroll.contentInsets = NSEdgeInsets(top: 2, left: 0, bottom: 25, right: 0)
        let view = ReadOnlyDocumentView(snapshot: NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)
        ]), fallbackHeight: 16)
        window.contentView!.addSubview(scroll)
        scroll.documentView = view
        scroll.tile()
        window.orderFront(nil)
        view.updateViewport()
        addTeardownBlock { window.orderOut(nil); window.close() }
        return (window, scroll, view)
    }
}
#endif
