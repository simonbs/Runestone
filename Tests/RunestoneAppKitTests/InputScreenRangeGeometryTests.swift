#if canImport(AppKit)
import AppKit
import CoreText
@testable import RunestoneAppKit
import XCTest

final class InputScreenRangeGeometryTests: XCTestCase {
    func testRangeStopsAtFirstVisualFragmentAndDirectionalRun() throws {
        let (window, _, view) = makeView("abc אבגד xyz " + String(repeating: "long text ", count: 10), width: 120)
        let result = try XCTUnwrap(InputScreenRangeGeometry.firstRect(for: NSRange(location: 0, length: view.content.length), in: view))
        XCTAssertEqual(result.actualRange.location, 0)
        XCTAssertGreaterThan(result.actualRange.length, 0)
        XCTAssertLessThan(result.actualRange.length, view.content.length)
        let placement = try XCTUnwrap(view.visibleLayout?.lines.first?.placements.first)
        let runs = try XCTUnwrap(CTLineGetGlyphRuns(placement.fragment.line) as? [CTRun])
        let firstRun = try XCTUnwrap(runs.first { CTRunGetStringRange($0).location == 0 })
        XCTAssertLessThanOrEqual(result.actualRange.upperBound, CTRunGetStringRange(firstRun).length)
        XCTAssertGreaterThan(result.rect.width, 0)
        XCTAssertTrue(window.convertToScreen(view.convert(placement.frame, to: nil)).intersects(result.rect))
    }

    func testBidirectionalRunBoundsAndHitTesting() throws {
        let (window, _, view) = makeView("abc אב👩‍💻גד xyz", width: 250)
        let placement = try XCTUnwrap(view.visibleLayout?.lines.first?.placements.first)
        let runs = try XCTUnwrap(CTLineGetGlyphRuns(placement.fragment.line) as? [CTRun])
        let run = try XCTUnwrap(runs.first { CTRunGetStatus($0).contains(.rightToLeft) })
        let runRange = CTRunGetStringRange(run)
        let result = try XCTUnwrap(InputScreenRangeGeometry.firstRect(for: NSRange(location: runRange.location,
                                                                                   length: view.content.length - runRange.location), in: view))
        XCTAssertEqual(result.actualRange, NSRange(location: runRange.location, length: runRange.length))
        let count = CTRunGetGlyphCount(run)
        var positions = [CGPoint](repeating: .zero, count: count)
        var advances = [CGSize](repeating: .zero, count: count)
        CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
        CTRunGetAdvances(run, CFRange(location: 0, length: 0), &advances)
        let minX = try XCTUnwrap(positions.map(\.x).min())
        let maxX = try XCTUnwrap(zip(positions, advances).map { $0.0.x + $0.1.width }.max())
        let screen = window.convertToScreen(view.convert(NSRect(x: minX, y: placement.frame.minY,
                                                                width: maxX - minX, height: placement.frame.height), to: nil))
        XCTAssertEqual(result.rect.minX, screen.minX, accuracy: 0.1)
        XCTAssertEqual(result.rect.maxX, screen.maxX, accuracy: 0.1)
        // Resolve both visual sides of a multi-scalar cluster beside RTL text.
        let cluster = (view.content.string as NSString).range(of: "👩‍💻")
        var leading: CGFloat?
        var trailing: (index: Int, x: CGFloat)?
        CTLineEnumerateCaretOffsets(placement.fragment.line) { x, index, isLeading, _ in
            if isLeading && index == cluster.location { leading = x }
            if !isLeading && index >= cluster.location && index < cluster.upperBound &&
                (trailing == nil || index > trailing!.index) { trailing = (index, x) }
        }
        let a = try XCTUnwrap(leading)
        let b = try XCTUnwrap(trailing?.x)
        XCTAssertNotEqual(a, b)
        for (fraction, expected) in [(CGFloat(0.1), cluster.location), (CGFloat(0.9), cluster.upperBound)] {
            let p = NSPoint(x: a + (b - a) * fraction, y: placement.frame.midY)
            let index = try XCTUnwrap(InputScreenRangeGeometry.characterIndex(for: window.convertPoint(toScreen: view.convert(p, to: nil)), in: view))
            XCTAssertEqual(index, expected)
        }
    }

    func testHiddenWrapWhitespaceReturnsCaretRange() throws {
        let text = String(repeating: "abc        def ", count: 8)
        var checked = false
        for width in [CGFloat(25), 30, 35, 40, 45, 50, 60, 75, 90] {
            let (window, _, view) = makeView(text, width: width)
            guard let placement = view.visibleLayout?.lines.first?.placements.first(where: { $0.fragment.hiddenLength > 0 }) else { continue }
            let location = placement.fragment.visibleRange.upperBound
            guard let expected = InputScreenCaretGeometry.rect(at: location, in: view) else { continue }
            let result = try XCTUnwrap(InputScreenRangeGeometry.firstRect(for: NSRange(location: location, length: 1), in: view))
            XCTAssertEqual(result.actualRange, NSRange(location: location, length: 0))
            XCTAssertEqual(result.rect, expected)
            checked = true
            _ = window
            break
        }
        XCTAssertTrue(checked)
    }

    func testHitTestingUsesScreenCoordinatesAndNeverSplitsSurrogate() throws {
        let (window, scroll, view) = makeView("a😀b\nsecond", width: 180)
        let layout = try XCTUnwrap(view.visibleLayout?.lines.first)
        let placement = try XCTUnwrap(layout.placements.first)
        let y = placement.frame.midY
        let start = window.convertPoint(toScreen: view.convert(NSPoint(x: 0, y: y), to: nil))
        XCTAssertEqual(InputScreenRangeGeometry.characterIndex(for: start, in: view), 0)
        let left = CTLineGetOffsetForStringIndex(placement.fragment.line, 1, nil)
        let right = CTLineGetOffsetForStringIndex(placement.fragment.line, 3, nil)
        for fraction in [CGFloat(0.25), 0.5, 0.75] {
            let point = NSPoint(x: left + (right - left) * fraction, y: y)
            let screen = window.convertPoint(toScreen: view.convert(point, to: nil))
            let index = try XCTUnwrap(InputScreenRangeGeometry.characterIndex(for: screen, in: view))
            let expected = fraction <= 0.5 ? 1 : 3
            if fraction != 0.5 { XCTAssertEqual(index, expected) }
            else { XCTAssertTrue(index == 1 || index == 3) }
        }
        let outside = window.convertPoint(toScreen: view.convert(NSPoint(x: -10, y: y), to: nil))
        XCTAssertNil(InputScreenRangeGeometry.characterIndex(for: outside, in: view))
        scroll.removeFromSuperview()
        XCTAssertNil(InputScreenRangeGeometry.characterIndex(for: start, in: view))
    }

    func testDragHitTestingClampsOutsideViewportToVisibleText() throws {
        let (window, scroll, view) = makeView("first\r\n😀last", width: 180)
        let layouts = try XCTUnwrap(view.visibleLayout?.lines)
        let last = try XCTUnwrap(layouts.last)
        let placement = try XCTUnwrap(last.placements.last)
        let edge = NSPoint(x: scroll.contentView.bounds.maxX - 1, y: placement.frame.midY)
        let outside = NSPoint(x: scroll.contentView.bounds.maxX + 80, y: scroll.contentView.bounds.maxY + 80)
        let expected = try XCTUnwrap(InputScreenRangeGeometry.characterIndex(
            for: window.convertPoint(toScreen: view.convert(edge, to: nil)), in: view))
        let actual = InputScreenRangeGeometry.characterIndexForDrag(
            for: window.convertPoint(toScreen: view.convert(outside, to: nil)), in: view)
        XCTAssertEqual(actual, expected)
        XCTAssertNotEqual(actual, (view.content.string as NSString).range(of: "😀").location + 1)
        scroll.removeFromSuperview()
        XCTAssertNil(InputScreenRangeGeometry.characterIndexForDrag(
            for: window.convertPoint(toScreen: view.convert(outside, to: nil)), in: view))
    }

    func testRangeUsesCurrentLayoutAfterResize() throws {
        let (window, scroll, view) = makeView(String(repeating: "word ", count: 20), width: 80)
        let first = try XCTUnwrap(view.visibleLayout?.lines.first?.placements.first)
        let start = first.fragment.range.upperBound
        let before = try XCTUnwrap(InputScreenRangeGeometry.firstRect(for: NSRange(location: start, length: 15), in: view))
        XCTAssertEqual(before.actualRange.location, start)
        scroll.setFrameSize(NSSize(width: 180, height: 100))
        scroll.tile()
        view.updateViewport()
        let after = try XCTUnwrap(InputScreenRangeGeometry.firstRect(for: NSRange(location: start, length: 15), in: view))
        XCTAssertEqual(after.actualRange.location, start)
        XCTAssertGreaterThan(after.actualRange.length, before.actualRange.length)
        XCTAssertGreaterThan(after.rect.minY, before.rect.minY)
        _ = window
    }

    func testEmptyLineAndInvalidRanges() throws {
        let (window, _, view) = makeView("\n😀", width: 180)
        let caret = try XCTUnwrap(InputScreenRangeGeometry.firstRect(for: NSRange(location: 0, length: 0), in: view))
        let screen = window.convertPoint(toScreen: view.convert(NSPoint(x: 2, y: 8), to: nil))
        XCTAssertEqual(InputScreenRangeGeometry.characterIndex(for: screen, in: view), 0)
        XCTAssertEqual(caret.actualRange, NSRange(location: 0, length: 0))
        XCTAssertNil(InputScreenRangeGeometry.firstRect(for: NSRange(location: 2, length: 0), in: view))
        XCTAssertNil(InputScreenRangeGeometry.firstRect(for: NSRange(location: 0, length: Int.max), in: view))
    }

    private func makeView(_ text: String, width: CGFloat) -> (NSWindow, NSScrollView, ReadOnlyDocumentView) {
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: width, height: 100),
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
