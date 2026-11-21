#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class SearchOccurrencePresentationTests: XCTestCase {
    func testOccurrencesArePresentedBelowTheFindPresentationAndRemovedWhenEmpty() throws {
        let (_, scroll, view) = makeView("let apple = 1\nlet apple = 2\n")
        view.setSearchOccurrences([.init(range: NSRange(location: 4, length: 5))])
        let overlay = try XCTUnwrap(view.searchOccurrencePresentationView)
        XCTAssertTrue(overlay.superview === scroll.contentView)
        XCTAssertEqual(overlay.frame, scroll.contentView.bounds)
        XCTAssertNil(overlay.hitTest(NSPoint(x: 10, y: 10)), "The presentation must not intercept editing")
        // The find bar's dimmed presentation, shown later, stays above it.
        view.setTextFinderMatches([NSRange(location: 0, length: 3)])
        let subviews = scroll.contentView.subviews
        let finder = try XCTUnwrap(view.textFinderPresentationView)
        XCTAssertLessThan(try XCTUnwrap(subviews.firstIndex(of: overlay)), try XCTUnwrap(subviews.firstIndex(of: finder)))
        view.setSearchOccurrences([])
        XCTAssertNil(view.searchOccurrencePresentationView)
        XCTAssertNil(overlay.superview)
    }

    func testReplacementPreviewKeepsOccurrenceStruckAndInsertsTextAfterItOnTheLine() throws {
        let (window, _, view) = makeView("let apple = 1\n")
        view.setSearchOccurrences([.init(range: NSRange(location: 4, length: 5), replacement: "strawberry")])
        let overlay = try XCTUnwrap(view.searchOccurrencePresentationView)
        let match = try XCTUnwrap(view.textFinderRects(for: NSRange(location: 4, length: 5)).first)
        let tail = try XCTUnwrap(view.textFinderRects(for: NSRange(location: 10, length: 1)).first)
        let content = try XCTUnwrap(window.contentView)
        let bitmap = try XCTUnwrap(content.bitmapImageRepForCachingDisplay(in: content.bounds))
        content.cacheDisplay(in: content.bounds, to: bitmap)
        func color(at point: NSPoint) throws -> NSColor {
            let inWindow = content.convert(overlay.convert(point, to: nil), from: nil)
            let scale = CGFloat(bitmap.pixelsWide) / content.bounds.width
            let pixel = try XCTUnwrap(bitmap.colorAt(x: Int(inWindow.x * scale), y: Int((content.bounds.height - inWindow.y) * scale)))
            return try XCTUnwrap(pixel.usingColorSpace(.sRGB))
        }
        let origin = overlay.convert(NSPoint.zero, from: view)
        // Just inside the plate's top edge, clear of glyphs: red over the occurrence, green after it.
        let struck = try color(at: NSPoint(x: origin.x + match.midX, y: origin.y + match.minY + 1))
        XCTAssertGreaterThan(struck.redComponent, struck.greenComponent + 0.05)
        let inserted = try color(at: NSPoint(x: origin.x + match.maxX + 12, y: origin.y + match.minY + 1))
        XCTAssertGreaterThan(inserted.greenComponent, inserted.redComponent + 0.05)
        // The "=" after the occurrence moved right by the insertion; its old place holds the insertion.
        XCTAssertLessThan(tail.minX, match.maxX + 40)
    }

    func testSelectedOccurrenceIsYellowAndOthersUseTheFindBarMatchPlate() throws {
        let (window, _, view) = makeView("let apple = 1\nlet apple = 2\n")
        let first = NSRange(location: 4, length: 5)
        let second = NSRange(location: 18, length: 5)
        view.setSearchOccurrences([.init(range: first), .init(range: second)])
        view.updateDisplaySelection(first)
        let overlay = try XCTUnwrap(view.searchOccurrencePresentationView)
        let content = try XCTUnwrap(window.contentView)
        let bitmap = try XCTUnwrap(content.bitmapImageRepForCachingDisplay(in: content.bounds))
        content.cacheDisplay(in: content.bounds, to: bitmap)
        func plateColor(_ range: NSRange) throws -> NSColor {
            let match = try XCTUnwrap(view.textFinderRects(for: range).first)
            let point = content.convert(overlay.convert(overlay.convert(NSPoint(x: match.midX, y: match.minY + 1), from: view), to: nil), from: nil)
            let scale = CGFloat(bitmap.pixelsWide) / content.bounds.width
            return try XCTUnwrap(bitmap.colorAt(x: Int(point.x * scale), y: Int((content.bounds.height - point.y) * scale))?.usingColorSpace(.sRGB))
        }
        // The warm yellow of the system's find indicator; the bitmap's color space shifts exact components.
        let selected = try plateColor(first)
        XCTAssertGreaterThan(selected.redComponent, 0.85)
        XCTAssertGreaterThan(selected.greenComponent, selected.blueComponent + 0.3)
        XCTAssertLessThan(selected.greenComponent, selected.redComponent - 0.03, "Warmer than a pure yellow")
        // The other occurrence has the find bar's neutral match plate.
        let other = try plateColor(second)
        XCTAssertEqual(other.redComponent, other.blueComponent, accuracy: 0.05)
        XCTAssertLessThan(other.redComponent, 0.95, "Darker than the editor's background")
    }

    func testPreviewedTextSitsOnTheLineBaseline() throws {
        let (_, _, view) = makeView("let apple = 1\n")
        let match = try XCTUnwrap(view.textFinderRects(for: NSRange(location: 4, length: 5)).first)
        let baseline = try XCTUnwrap(view.baseline(ofLineContaining: match))
        XCTAssertGreaterThan(baseline, match.minY)
        XCTAssertLessThan(baseline, match.maxY)
        XCTAssertNil(view.baseline(ofLineContaining: match.offsetBy(dx: 0, dy: 10_000)))
    }

    private func makeView(_ text: String, width: CGFloat = 320, height: CGFloat = 80) -> (NSWindow, NSScrollView, ReadOnlyDocumentView) {
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
