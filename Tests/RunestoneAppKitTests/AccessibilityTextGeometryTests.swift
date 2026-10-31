#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class AccessibilityTextGeometryTests: XCTestCase {
    func testVisibleRangeUsesViewportAndPreservesVisibleLineDelimiters() throws {
        let text = "first\nsecond\n" + String(repeating: "word ", count: 80)
        let (window, scroll, view) = makeView(text, width: 150, height: 60)
        let range = try XCTUnwrap(AccessibilityTextGeometry.visibleRange(in: view), describe(view))
        XCTAssertEqual(range.location, 0, describe(view))
        XCTAssertGreaterThanOrEqual(range.length, ("first\n" as NSString).length)
        XCTAssertLessThan(range.upperBound, (text as NSString).length)
        XCTAssertEqual((text as NSString).substring(with: NSRange(location: range.location, length: 6)), "first\n")
        XCTAssertEqual(view.visibleLayout?.viewport, scroll.contentView.bounds)
        withExtendedLifetime(window) {}
    }

    func testEmptyDocumentAndEmptyLineReportRealOffsets() throws {
        for (text, expected) in [("", NSRange(location: 0, length: 0)), ("\nx", NSRange(location: 0, length: 2)),
                                 ("\r\nx", NSRange(location: 0, length: 3))] {
            let (window, _, view) = makeView(text, width: 150, height: 80)
            XCTAssertEqual(AccessibilityTextGeometry.visibleRange(in: view), expected)
            withExtendedLifetime(window) {}
        }
    }

    func testScrollAndStaleViewportNeverReportOldVisibleRange() throws {
        let text = (0..<100).map { "line \($0)\n" }.joined()
        let (window, scroll, view) = makeView(text, width: 150, height: 65)
        let before = try XCTUnwrap(AccessibilityTextGeometry.visibleRange(in: view), describe(view))
        scroll.contentView.postsBoundsChangedNotifications = false
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 200))
        XCTAssertNil(AccessibilityTextGeometry.visibleRange(in: view))
        scroll.contentView.postsBoundsChangedNotifications = true
        scroll.reflectScrolledClipView(scroll.contentView)
        view.updateViewport()
        let after = try XCTUnwrap(AccessibilityTextGeometry.visibleRange(in: view), describe(view))
        XCTAssertGreaterThan(after.location, before.location)
        XCTAssertLessThanOrEqual(after.upperBound, (text as NSString).length)
        withExtendedLifetime(window) {}
    }

    func testVisibleRangeDoesNotIncludeTrailingHiddenWrapWhitespace() throws {
        let text = String(repeating: "abc        def ", count: 40)
        var checked = false
        for width in [CGFloat(25), 30, 35, 40, 45, 50, 60, 75, 90] {
            let (window, scroll, view) = makeView(text, width: width, height: 24)
            guard let line = view.visibleLayout?.lines.first,
                  let placement = line.placements.first(where: { $0.fragment.hiddenLength > 0 }),
                  scroll.contentView.bounds.contains(placement.frame),
                  let range = AccessibilityTextGeometry.visibleRange(in: view) else { continue }
            let visibleEnd = line.line.location + placement.fragment.visibleRange.upperBound
            XCTAssertLessThanOrEqual(range.upperBound, visibleEnd)
            checked = true
            withExtendedLifetime(window) {}
            break
        }
        XCTAssertTrue(checked, "Expected a fully visible fragment with hidden wrap whitespace")
    }

    func testFrameForRangeRequiresCompleteRequestedRangeAndCurrentViewport() throws {
        let (window, scroll, view) = makeView("abc אבגד xyz\n" + String(repeating: "line\n", count: 60), width: 140, height: 70)
        let exact = NSRange(location: 0, length: 2)
        let input = try XCTUnwrap(InputScreenRangeGeometry.firstRect(for: exact, in: view))
        XCTAssertEqual(input.actualRange, exact)
        XCTAssertEqual(AccessibilityTextGeometry.frame(for: exact, in: view), input.rect)
        XCTAssertNil(AccessibilityTextGeometry.frame(for: NSRange(location: 0, length: view.content.length), in: view))
        XCTAssertNil(AccessibilityTextGeometry.frame(for: NSRange(location: 0, length: Int.max), in: view))
        scroll.contentView.postsBoundsChangedNotifications = false
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 200))
        XCTAssertNil(AccessibilityTextGeometry.frame(for: exact, in: view))
        scroll.contentView.postsBoundsChangedNotifications = true
        scroll.reflectScrolledClipView(scroll.contentView)
        view.updateViewport()
        XCTAssertNil(AccessibilityTextGeometry.frame(for: exact, in: view))
        withExtendedLifetime(window) {}
    }

    func testPointMapsBothSidesOfAnEmojiToItsComposedRange() throws {
        let (window, _, view) = makeView("A😀B", width: 180, height: 80)
        let emoji = NSRange(location: 1, length: 2)
        let frame = try XCTUnwrap(AccessibilityTextGeometry.frame(for: emoji, in: view))
        for fraction in [CGFloat(0.2), 0.8] {
            let point = NSPoint(x: frame.minX + frame.width * fraction, y: frame.midY)
            XCTAssertEqual(AccessibilityTextGeometry.range(at: point, in: view), emoji)
        }
        withExtendedLifetime(window) {}
    }

    func testPointOutsideTextAndStaleViewportIsUnavailable() throws {
        let (window, scroll, view) = makeView("abc\n" + String(repeating: "line\n", count: 50), width: 150, height: 65)
        let glyph = try XCTUnwrap(AccessibilityTextGeometry.frame(for: NSRange(location: 0, length: 1), in: view))
        let inside = NSPoint(x: glyph.midX, y: glyph.midY)
        XCTAssertEqual(AccessibilityTextGeometry.range(at: inside, in: view), NSRange(location: 0, length: 1))
        let outside = window.convertPoint(toScreen: view.convert(NSPoint(x: -20, y: 2), to: nil))
        XCTAssertNil(AccessibilityTextGeometry.range(at: outside, in: view))
        // An insertion hit in blank line area must not invent a character frame.
        let beyondGlyphs = window.convertPoint(toScreen: view.convert(NSPoint(x: 130, y: 8), to: nil))
        XCTAssertNil(AccessibilityTextGeometry.range(at: beyondGlyphs, in: view))
        scroll.contentView.postsBoundsChangedNotifications = false
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 200))
        XCTAssertNil(AccessibilityTextGeometry.range(at: inside, in: view))
        scroll.contentView.postsBoundsChangedNotifications = true
        scroll.reflectScrolledClipView(scroll.contentView)
        view.updateViewport()
        XCTAssertNotEqual(AccessibilityTextGeometry.range(at: inside, in: view), NSRange(location: 0, length: 1))
        view.retireInputView()
        XCTAssertNil(AccessibilityTextGeometry.range(at: inside, in: view))
        withExtendedLifetime(window) {}
    }

    func testClippedAncestorLimitsVisibleRangeFrameAndPoint() throws {
        let (window, scroll, view) = makeView("abcdefghijk", width: 150, height: 80)
        let first = NSRange(location: 0, length: 1)
        let clipped = NSRange(location: 8, length: 1)
        let firstScreenFrame = try XCTUnwrap(AccessibilityTextGeometry.frame(for: first, in: view))
        let clippedScreenFrame = try XCTUnwrap(AccessibilityTextGeometry.frame(for: clipped, in: view))
        XCTAssertNotNil(AccessibilityTextGeometry.visibleRange(in: view))

        // The scroll view keeps its original clip bounds and complete layout;
        // an intermediate ancestor clips most of it without hiding any view.
        let ancestor = NSView(frame: NSRect(x: 0, y: 0, width: 30, height: 80))
        ancestor.clipsToBounds = true
        scroll.removeFromSuperview()
        ancestor.addSubview(scroll)
        window.contentView!.addSubview(ancestor)
        scroll.tile()
        view.updateViewport()
        XCTAssertEqual(view.visibleLayout?.viewport, scroll.contentView.bounds)
        XCTAssertLessThan(view.visibleRect.width, scroll.contentView.bounds.width)
        XCTAssertFalse(view.isHiddenOrHasHiddenAncestor)
        // The only text fragment extends outside the ancestor, so its complete
        // visible range is unavailable even though its first character fits.
        XCTAssertNil(AccessibilityTextGeometry.visibleRange(in: view))
        XCTAssertNotNil(AccessibilityTextGeometry.frame(for: first, in: view))
        XCTAssertEqual(AccessibilityTextGeometry.range(at: NSPoint(x: firstScreenFrame.midX, y: firstScreenFrame.midY), in: view), first)
        XCTAssertNil(AccessibilityTextGeometry.frame(for: clipped, in: view))
        XCTAssertNil(AccessibilityTextGeometry.range(at: NSPoint(x: clippedScreenFrame.midX, y: clippedScreenFrame.midY), in: view))
        withExtendedLifetime(window) {}
    }

    func testHiddenViewAncestorAndOrderedOutWindowDoNotExposeGeometry() throws {
        let (window, scroll, view) = makeView("abc", width: 150, height: 80)
        let requested = NSRange(location: 0, length: 1)
        let frame = try XCTUnwrap(AccessibilityTextGeometry.frame(for: requested, in: view))
        let point = NSPoint(x: frame.midX, y: frame.midY)
        XCTAssertNotNil(AccessibilityTextGeometry.visibleRange(in: view))
        XCTAssertEqual(AccessibilityTextGeometry.range(at: point, in: view), requested)
        func assertUnavailable(file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertNil(AccessibilityTextGeometry.visibleRange(in: view), file: file, line: line)
            XCTAssertNil(AccessibilityTextGeometry.frame(for: requested, in: view), file: file, line: line)
            XCTAssertNil(AccessibilityTextGeometry.range(at: point, in: view), file: file, line: line)
        }
        view.isHidden = true
        assertUnavailable()
        view.isHidden = false
        scroll.isHidden = true
        assertUnavailable()
        scroll.isHidden = false
        XCTAssertNotNil(AccessibilityTextGeometry.visibleRange(in: view))
        window.orderOut(nil)
        XCTAssertFalse(window.isVisible)
        assertUnavailable()
    }

    func testDetachedAndRetiredViewsDoNotExposeGeometry() throws {
        let (window, scroll, view) = makeView("abc", width: 150, height: 80)
        XCTAssertNotNil(AccessibilityTextGeometry.visibleRange(in: view))
        scroll.documentView = nil
        XCTAssertNil(AccessibilityTextGeometry.visibleRange(in: view))
        XCTAssertNil(AccessibilityTextGeometry.frame(for: NSRange(location: 0, length: 0), in: view))
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        view.retireInputView()
        XCTAssertNil(AccessibilityTextGeometry.visibleRange(in: view))
        XCTAssertNil(AccessibilityTextGeometry.frame(for: NSRange(location: 0, length: 0), in: view))
        withExtendedLifetime(window) {}
    }

    private func describe(_ view: ReadOnlyDocumentView) -> String {
        let clip = view.enclosingScrollView?.contentView.bounds
        let layout = view.visibleLayout
        let lines = layout?.lines.map { item in
            "location=\(item.line.location), length=\(item.line.data.length), total=\(item.line.data.totalLength), placements=\(item.placements.map { "\($0.fragment.visibleRange)/\($0.fragment.range) frame=\($0.frame)" })"
        } ?? []
        return "clip=\(String(describing: clip)), viewport=\(String(describing: layout?.viewport)), complete=\(String(describing: layout?.isComplete)), lines=\(lines)"
    }

    private func makeView(_ text: String, width: CGFloat, height: CGFloat) -> (NSWindow, NSScrollView, ReadOnlyDocumentView) {
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: width, height: height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let scroll = NSScrollView(frame: window.contentView!.bounds)
        let snapshot = NSAttributedString(string: text, attributes: [.font: NSFont.monospacedSystemFont(ofSize: 16, weight: .regular)])
        let view = ReadOnlyDocumentView(snapshot: snapshot, fallbackHeight: 16)
        window.contentView!.addSubview(scroll)
        scroll.documentView = view
        scroll.tile()
        view.updateViewport()
        window.isReleasedWhenClosed = false
        window.orderFront(nil)
        XCTAssertTrue(window.isVisible, "The test must establish an ordered window without key focus")
        addTeardownBlock { window.orderOut(nil); window.close() }
        return (window, scroll, view)
    }
}
#endif
