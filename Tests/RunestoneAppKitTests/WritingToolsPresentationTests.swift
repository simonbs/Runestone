#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

final class WritingToolsPresentationTests: XCTestCase {
    func testGlyphPreviewIsTransparentAndIndependentOfAnimationHiding() throws {
        let (_, view) = makeView("Some preview text\nAnother line")
        let range = NSRange(location: 0, length: 17)
        let before = try XCTUnwrap(view.writingToolsPreview(for: range))
        view.setWritingToolsPresentation(hiddenRanges: [range], dimmedRanges: [])
        let hidden = try XCTUnwrap(view.writingToolsPreview(for: range))
        XCTAssertEqual(before.previewImage.dataProvider?.data as Data?, hidden.previewImage.dataProvider?.data as Data?)
        let bitmap = NSBitmapImageRep(cgImage: before.previewImage)
        var transparent = 0
        var glyphs = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                let alpha = try XCTUnwrap(bitmap.colorAt(x: x, y: y)).alphaComponent
                if alpha < 0.01 { transparent += 1 }
                else { glyphs += 1 }
            }
        }
        XCTAssertGreaterThan(transparent, glyphs)
        XCTAssertGreaterThan(glyphs, 0)
        XCTAssertEqual(view.content.string, "Some preview text\nAnother line")
    }

    func testPreviewsStayViewportBoundedAndRejectInvalidRanges() throws {
        let (scroll, view) = makeView(String(repeating: "abc אבגד xyz wrap here\n", count: 1000))
        let preview = try XCTUnwrap(view.writingToolsPreview(for: NSRange(location: 0, length: view.content.length)))
        XCTAssertLessThanOrEqual(CGFloat(preview.previewImage.height), ceil(scroll.contentView.bounds.height + 2) * 2)
        XCTAssertTrue(preview.candidateRects.allSatisfy { view.visibleRect.contains($0.rectValue) })
        XCTAssertNil(view.writingToolsPreview(for: NSRange(location: NSNotFound, length: 1)))
        XCTAssertNil(view.writingToolsPreview(for: NSRange(location: 900000, length: 1)))
        XCTAssertNil(view.writingToolsPreview(for: NSRect(x: CGFloat.infinity, y: 0, width: 10, height: 10)))
    }

    func testTemporaryPreviewDoesNotAlterCanonicalTextOrRevision() throws {
        let (_, view) = makeView("This are wrong.")
        let revision = view.contentRevision
        view.showWritingToolsTemporaryText("This is wrong.")
        let previewView = view.writingToolsPreviewView
        XCTAssertFalse(previewView === view)
        XCTAssertEqual(previewView.content.string, "This is wrong.")
        XCTAssertEqual(view.content.string, "This are wrong.")
        XCTAssertEqual(view.contentRevision, revision)
        XCTAssertNil(view.writingToolsTemporaryPresentation?.hitTest(NSPoint(x: 5, y: 5)))
        view.showWritingToolsTemporaryText(nil)
        XCTAssertTrue(view.writingToolsPreviewView === view)
        XCTAssertEqual(view.contentRevision, revision)
    }

    func testOverlappingAnimationsNeverRevealUnderlyingGlyphs() throws {
        let (_, view) = makeView("Some preview text")
        let full = NSRange(location: 0, length: view.content.length)
        let visible = try draw(view)
        view.setWritingToolsPresentation(hiddenRanges: [full, NSRange(location: 5, length: 7)], dimmedRanges: [])
        let hidden = try draw(view)
        XCTAssertNotEqual(visible.tiffRepresentation, hidden.tiffRepresentation)
        // A second overlapping range must be equivalent to hiding their union.
        view.setWritingToolsPresentation(hiddenRanges: [full], dimmedRanges: [])
        let union = try draw(view)
        XCTAssertEqual(hidden.tiffRepresentation, union.tiffRepresentation)
        view.setWritingToolsPresentation(hiddenRanges: [full], dimmedRanges: [full, full])
        XCTAssertEqual(try draw(view).tiffRepresentation, hidden.tiffRepresentation, "Hidden animations take precedence over dimmed ones")
        view.setWritingToolsPresentation(hiddenRanges: [], dimmedRanges: [])
        XCTAssertEqual(try draw(view).tiffRepresentation, visible.tiffRepresentation)
    }

    private func draw(_ view: ReadOnlyDocumentView) throws -> NSBitmapImageRep {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 240, pixelsHigh: 90,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let graphics = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = graphics
        graphics.cgContext.setFillColor(NSColor.white.cgColor)
        graphics.cgContext.fill(CGRect(x: 0, y: 0, width: 240, height: 90))
        graphics.cgContext.translateBy(x: 0, y: 90)
        graphics.cgContext.scaleBy(x: 1, y: -1)
        view.draw(view.visibleRect)
        return bitmap
    }

    private func makeView(_ text: String) -> (NSScrollView, ReadOnlyDocumentView) {
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 240, height: 90),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let scroll = NSScrollView(frame: window.contentView!.bounds)
        let view = ReadOnlyDocumentView(content: NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 16, weight: .regular), .foregroundColor: NSColor.black
        ]))
        window.contentView!.addSubview(scroll)
        scroll.documentView = view
        scroll.tile()
        window.orderFront(nil)
        view.updateViewport()
        addTeardownBlock { window.orderOut(nil); window.close() }
        return (scroll, view)
    }
}
#endif
