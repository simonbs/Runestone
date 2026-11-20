#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class TextFinderGeometryTests: XCTestCase {
    func testWrappedMultilineAndBidirectionalMatchesHaveSeparateVisibleRects() throws {
        let text = "abc אבגד xyz " + String(repeating: "wrapped text ", count: 12) + "\nnext line"
        let (_, _, view) = makeView(text, width: 180, height: 120)
        let rects = view.textFinderRects(for: NSRange(location: 0, length: (text as NSString).length))
        XCTAssertGreaterThan(rects.count, 2)
        XCTAssertGreaterThan(Set(rects.map(\.minY)).count, 1)
        XCTAssertTrue(rects.allSatisfy { view.visibleRect.contains($0) && $0.minX >= view.gutterWidth })
        let bidi = view.textFinderRects(for: NSRange(location: 2, length: 4))
        XCTAssertGreaterThan(bidi.count, 1, "Keep separate bidi runs instead of highlighting unrelated text between them")
        XCTAssertFalse(view.textFinderVisibleCharacterRanges.isEmpty)
    }

    func testPartiallyVisibleFragmentsRemainSearchableAndHighlightsClipToViewport() throws {
        let (_, scroll, view) = makeView(String(repeating: "searchable line\n", count: 80), width: 200, height: 55)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 8))
        scroll.reflectScrolledClipView(scroll.contentView)
        view.updateViewport()
        XCTAssertEqual(view.textFinderVisibleCharacterRanges.first?.location, 0)
        let rects = view.textFinderRects(for: NSRange(location: 0, length: 10))
        XCTAssertFalse(rects.isEmpty)
        XCTAssertTrue(rects.allSatisfy { scroll.contentView.bounds.contains($0) })
        XCTAssertEqual(rects.first?.minY, scroll.contentView.bounds.minY)
    }

    func testInvalidUnicodeHiddenAndStaleViewportHaveNoHighlights() throws {
        let (_, scroll, view) = makeView("A😀B\n" + String(repeating: "line\n", count: 80), width: 180, height: 70)
        XCTAssertFalse(view.textFinderRects(for: NSRange(location: 1, length: 2)).isEmpty)
        XCTAssertTrue(view.textFinderRects(for: NSRange(location: 1, length: 1)).isEmpty)
        XCTAssertTrue(view.textFinderRects(for: NSRange(location: NSNotFound, length: 1)).isEmpty)
        scroll.contentView.postsBoundsChangedNotifications = false
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 200))
        XCTAssertTrue(view.textFinderVisibleCharacterRanges.isEmpty)
        XCTAssertTrue(view.textFinderRects(for: NSRange(location: 1, length: 2)).isEmpty)
        view.updateViewport()
        XCTAssertGreaterThan(try XCTUnwrap(view.textFinderVisibleCharacterRanges.first).location, 0)
        view.isHidden = true
        XCTAssertTrue(view.textFinderVisibleCharacterRanges.isEmpty)
    }

    private func makeView(_ text: String, width: CGFloat, height: CGFloat) -> (NSWindow, NSScrollView, ReadOnlyDocumentView) {
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: width, height: height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let scroll = NSScrollView(frame: window.contentView!.bounds)
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
