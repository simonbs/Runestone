#if canImport(AppKit)
import AppKit
import RunestoneAppKit
import XCTest

final class ReadOnlyDocumentPublicAPITests: XCTestCase {
    func testContentIsCopiedOnCreationAndReplacement() {
        let input = NSMutableAttributedString(string: "original", attributes: [.font: NSFont.systemFont(ofSize: 14)])
        let view = ReadOnlyDocumentView(content: input)
        input.replaceCharacters(in: NSRange(location: 0, length: input.length), with: "changed")
        XCTAssertEqual(view.content.string, "original")

        let replacement = NSMutableAttributedString(string: "replacement", attributes: [.font: NSFont.systemFont(ofSize: 24)])
        view.setContent(replacement)
        replacement.replaceCharacters(in: NSRange(location: 0, length: replacement.length), with: "changed")
        XCTAssertEqual(view.content.string, "replacement")
        XCTAssertEqual((view.content.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize, 24)

        let sameTextNewAttributes = NSAttributedString(string: "replacement", attributes: [.font: NSFont.systemFont(ofSize: 12)])
        view.setContent(sameTextNewAttributes)
        XCTAssertEqual((view.content.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)?.pointSize, 12)
    }

    func testAttributeOnlyReplacementRelayoutsTheDocument() {
        let string = "first\nsecond\nthird"
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 180, height: 20))
        let small = NSAttributedString(string: string, attributes: [.font: NSFont.systemFont(ofSize: 12)])
        let view = ReadOnlyDocumentView(content: small)
        scroll.documentView = view
        scroll.tile()
        view.layoutSubtreeIfNeeded()
        let smallHeight = view.frame.height

        let large = NSAttributedString(string: string, attributes: [.font: NSFont.systemFont(ofSize: 48)])
        view.setContent(large)
        XCTAssertGreaterThan(view.frame.height, smallHeight)
    }

    func testReplacementIsDrawn() throws {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 180, height: 80))
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: ""))
        scroll.documentView = view
        scroll.tile()
        view.layoutSubtreeIfNeeded()
        view.setContent(NSAttributedString(string: "visible", attributes: [
            .font: NSFont.systemFont(ofSize: 24), .foregroundColor: NSColor.black
        ]))

        let image = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 180, pixelsHigh: 80,
                                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                   isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let graphics = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: image))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        graphics.cgContext.translateBy(x: 0, y: CGFloat(image.pixelsHigh))
        graphics.cgContext.scaleBy(x: 1, y: -1)
        view.draw(scroll.contentView.bounds)
        NSGraphicsContext.restoreGraphicsState()
        let bytes = try XCTUnwrap(image.bitmapData)
        XCTAssertTrue((0..<image.pixelsHigh).contains { y in
            (0..<image.pixelsWide).contains { x in bytes[y * image.bytesPerRow + x * 4 + 3] != 0 }
        })
    }

    func testReplacingScrolledDocumentResetsAndClampsViewport() {
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14)]
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 180, height: 80))
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: String(repeating: "long line\n", count: 200), attributes: attributes))
        scroll.documentView = view
        scroll.tile()
        view.layoutSubtreeIfNeeded()
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 500))
        XCTAssertGreaterThan(scroll.contentView.bounds.minY, 0)

        view.setContent(NSAttributedString(string: "short", attributes: attributes))
        XCTAssertEqual(scroll.contentView.bounds.minY, 0, accuracy: 0.01)
        XCTAssertEqual(view.content.string, "short")
        XCTAssertGreaterThanOrEqual(view.frame.height, scroll.contentView.bounds.height)
        XCTAssertLessThanOrEqual(scroll.contentView.bounds.maxY, view.frame.height + 0.01)

        view.setContent(NSAttributedString(string: ""))
        XCTAssertEqual(scroll.contentView.bounds.minY, 0, accuracy: 0.01)
        XCTAssertEqual(view.content.string, "")
        view.setContent(NSAttributedString(string: String(repeating: "new line\n", count: 100), attributes: attributes))
        XCTAssertGreaterThan(view.frame.height, scroll.contentView.bounds.height)
        XCTAssertEqual(scroll.contentView.bounds.minY, 0, accuracy: 0.01)
    }
}
#endif
