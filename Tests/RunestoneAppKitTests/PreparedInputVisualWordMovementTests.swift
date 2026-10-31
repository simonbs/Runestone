#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class PreparedInputVisualWordMovementTests: XCTestCase {
    func testVisualWordMovementSkipsSeparatorsAndStopsAtWordEdges() {
        let (window, _, view) = makeView("one, two!", width: 240, height: 80)
        XCTAssertEqual(PreparedInputVisualWordMovement.destination(from: 0, direction: .right, in: view), .moved(3))
        XCTAssertEqual(PreparedInputVisualWordMovement.destination(from: 3, direction: .right, in: view), .moved(8))
        XCTAssertEqual(PreparedInputVisualWordMovement.destination(from: 8, direction: .left, in: view), .moved(5))
        XCTAssertEqual(PreparedInputVisualWordMovement.destination(from: 5, direction: .left, in: view), .moved(0))
        withExtendedLifetime(window) {}
    }

    func testEmojiAndCombiningSequenceRemainWholeVisualTargets() {
        let text = "e\u{301}cho 👩‍💻 next"
        let (window, _, view) = makeView(text, width: 320, height: 80)
        let emoji = (text as NSString).range(of: "👩‍💻")
        let first = (text as NSString).range(of: "e\u{301}cho")
        let last = (text as NSString).range(of: "next")
        XCTAssertEqual(PreparedInputVisualWordMovement.destination(from: first.location, direction: .right, in: view), .moved(first.upperBound))
        XCTAssertEqual(PreparedInputVisualWordMovement.destination(from: first.upperBound, direction: .right, in: view), .moved(emoji.upperBound))
        XCTAssertEqual(PreparedInputVisualWordMovement.destination(from: emoji.upperBound, direction: .right, in: view), .moved(last.upperBound))
        XCTAssertEqual(PreparedInputVisualWordMovement.destination(from: last.location, direction: .left, in: view), .moved(emoji.location))
        XCTAssertEqual(PreparedInputVisualWordMovement.destination(from: first.location + 1, direction: .right, in: view), .unavailable)
        withExtendedLifetime(window) {}
    }

    func testCrossingVisibleCRLFPreservesTheDelimiter() {
        let (window, _, view) = makeView("one\r\ntwo", width: 200, height: 100)
        XCTAssertEqual(PreparedInputVisualWordMovement.destination(from: 3, direction: .right, in: view), .moved(8))
        XCTAssertEqual(PreparedInputVisualWordMovement.destination(from: 5, direction: .left, in: view), .moved(0))
        XCTAssertEqual(PreparedInputVisualWordMovement.destination(from: 4, direction: .left, in: view), .unavailable)
        XCTAssertEqual(PreparedInputVisualWordMovement.destination(from: 0, direction: .left, in: view), .boundary)
        withExtendedLifetime(window) {}
    }

    func testBidirectionalCaretAmbiguityIsRejected() {
        let text = "ab אבגד cd"
        let (window, _, view) = makeView(text, width: 300, height: 80)
        let junction = (text as NSString).range(of: "א").location
        XCTAssertEqual(PreparedInputVisualWordMovement.destination(from: junction, direction: .right, in: view), .unavailable)
        withExtendedLifetime(window) {}
    }

    func testDetachedClippedAndWorkLimitDoNotGuess() {
        let (window, scroll, view) = makeView("one\ntwo\nthree", width: 160, height: 17)
        XCTAssertEqual(PreparedInputVisualWordMovement.destination(from: 3, direction: .right, in: view), .unavailable)
        scroll.removeFromSuperview()
        XCTAssertEqual(PreparedInputVisualWordMovement.destination(from: 0, direction: .right, in: view), .unavailable)
        withExtendedLifetime(window) {}

        let (longWindow, _, longView) = makeView(String(repeating: "a", count: 200), width: 3000, height: 70)
        XCTAssertEqual(PreparedInputVisualWordMovement.destination(from: 0, direction: .right, in: longView), .unavailable)
        withExtendedLifetime(longWindow) {}
    }

    private func makeView(_ text: String, width: CGFloat, height: CGFloat) -> (NSWindow, NSScrollView, ReadOnlyDocumentView) {
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: width, height: height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let scroll = NSScrollView(frame: window.contentView!.bounds)
        let view = ReadOnlyDocumentView(snapshot: NSAttributedString(string: text,
            attributes: [.font: NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)]), fallbackHeight: 16)
        window.contentView!.addSubview(scroll)
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        return (window, scroll, view)
    }
}
#endif
