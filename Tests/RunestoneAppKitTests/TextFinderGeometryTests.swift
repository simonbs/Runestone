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

    func testPresentationDimsGutterDrawsReadableMatchesAndClearsWithoutEditing() throws {
        let text = "mark other text"
        let (_, scroll, view) = makeView(text, width: 220, height: 80)
        let range = NSRange(location: 0, length: 4)
        scroll.backgroundColor = .white
        view.setTextFinderMatches([range])
        let overlay = try XCTUnwrap(view.textFinderPresentationView)
        XCTAssertNil(overlay.hitTest(.zero))
        let rect = try XCTUnwrap(view.textFinderRects(for: range).first)

        func render() throws -> NSBitmapImageRep {
            let image = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 220, pixelsHigh: 80,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
            let graphics = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: image))
            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }
            NSGraphicsContext.current = graphics
            graphics.cgContext.setFillColor(NSColor(calibratedWhite: 0.4, alpha: 1).cgColor)
            graphics.cgContext.fill(CGRect(x: 0, y: 0, width: 220, height: 80))
            graphics.cgContext.translateBy(x: 0, y: 80)
            graphics.cgContext.scaleBy(x: 1, y: -1)
            overlay.draw(overlay.bounds)
            return image
        }
        let image = try render()
        let dimmed = try XCTUnwrap(image.colorAt(x: 215, y: 75)?.usingColorSpace(.deviceRGB))
        let original = try XCTUnwrap(NSColor(calibratedWhite: 0.4, alpha: 1).usingColorSpace(.deviceRGB))
        XCTAssertLessThan(dimmed.redComponent, original.redComponent - 0.05)
        let gutter = try XCTUnwrap(image.colorAt(x: 1, y: 75)?.usingColorSpace(.deviceRGB))
        XCTAssertEqual(gutter.redComponent, dimmed.redComponent, accuracy: 0.01)
        var fillPixels = 0
        var blackPixels = 0
        for y in Int(rect.minY)..<Int(rect.maxY) {
            for x in Int(rect.minX)..<Int(rect.maxX) {
                let color = try XCTUnwrap(image.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB))
                if color.redComponent > dimmed.redComponent + 0.1 && color.greenComponent > dimmed.greenComponent + 0.1 { fillPixels += 1 }
                if color.redComponent < 0.1 && color.greenComponent < 0.1 { blackPixels += 1 }
            }
        }
        XCTAssertGreaterThan(fillPixels, 0)
        XCTAssertGreaterThan(blackPixels, 0, "Match glyphs must remain readable over their bright plate")
        overlay.needsDisplay = false
        XCTAssertTrue(view.selectAndRevealDocumentRange(range))
        XCTAssertTrue(overlay.needsDisplay)
        let selected = try render()
        XCTAssertNotEqual(selected.tiffRepresentation, image.tiffRepresentation)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: -4))
        view.updateViewport()
        XCTAssertEqual(overlay.frame, scroll.contentView.bounds)
        view.setTextFinderMatches([])
        XCTAssertNil(view.textFinderPresentationView)
        XCTAssertEqual(view.content.string, text)
        XCTAssertEqual(view.presentedSelectionRange, range)
        view.setTextFinderMatches([range])
        let retiredOverlay = try XCTUnwrap(view.textFinderPresentationView)
        view.retireInputView()
        XCTAssertNil(retiredOverlay.superview)
        XCTAssertNil(view.textFinderPresentationView)
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
