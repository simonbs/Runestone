#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class InputScreenCaretGeometryTests: XCTestCase {
    func testEmptyAndTrailingLinesHaveScreenCarets() throws {
        let (window, scroll, view) = makeView("")
        let empty = try XCTUnwrap(InputScreenCaretGeometry.rect(at: 0, in: view))
        XCTAssertEqual(empty, window.convertToScreen(view.convert(NSRect(x: 0, y: 0, width: 1, height: 16), to: nil)))
        view.setContent(NSAttributedString(string: "a\n", attributes: [.font: NSFont.systemFont(ofSize: 16)]))
        let trailing = try XCTUnwrap(InputScreenCaretGeometry.rect(at: 2, in: view))
        let prior = try XCTUnwrap(InputScreenCaretGeometry.rect(at: 0, in: view))
        XCTAssertLessThan(trailing.minY, prior.minY)
        _ = scroll
    }

    func testCaretTracksScrollAndDetachedViewHasNoScreenGeometry() throws {
        let (window, scroll, view) = makeView((0..<30).map { "line \($0)" }.joined(separator: "\n"))
        let before = try XCTUnwrap(InputScreenCaretGeometry.rect(at: 0, in: view))
        let original = scroll.contentView.bounds.origin
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 5))
        view.updateViewport()
        let after = try XCTUnwrap(InputScreenCaretGeometry.rect(at: 0, in: view))
        XCTAssertEqual(after.minY - before.minY, scroll.contentView.bounds.minY - original.y, accuracy: 0.01)
        scroll.removeFromSuperview()
        XCTAssertNil(InputScreenCaretGeometry.rect(at: 0, in: view))
        _ = window
    }

    func testWrapBoundaryUsesDownstreamFragmentOnlyWhenVisible() throws {
        let (window, scroll, view) = makeView(String(repeating: "word ", count: 40), width: 80, height: 10)
        let first = try XCTUnwrap(view.visibleLayout?.lines.first?.placements.first)
        let boundary = first.fragment.range.upperBound
        XCTAssertNil(InputScreenCaretGeometry.rect(at: boundary, in: view))
        scroll.contentView.scroll(to: NSPoint(x: 0, y: first.frame.maxY + 1))
        view.updateViewport()
        let rect = try XCTUnwrap(InputScreenCaretGeometry.rect(at: boundary, in: view))
        let downstream = try XCTUnwrap(view.visibleLayout?.lines.first?.placements.first {
            $0.fragment.range.location == boundary
        })
        let expected = try XCTUnwrap(InputCaretGeometry.rect(for: downstream, lineStart: 0,
                                                              documentOffset: boundary, caretWidth: 1))
        XCTAssertEqual(rect, window.convertToScreen(view.convert(expected, to: nil)))
    }

    private func makeView(_ text: String, width: CGFloat = 180, height: CGFloat = 80) -> (NSWindow, NSScrollView, ReadOnlyDocumentView) {
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: width, height: height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let scroll = NSScrollView(frame: window.contentView!.bounds)
        let view = ReadOnlyDocumentView(snapshot: NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 16)]), fallbackHeight: 16)
        window.contentView!.addSubview(scroll)
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        return (window, scroll, view)
    }
}
#endif
