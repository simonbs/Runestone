#if canImport(AppKit)
import AppKit
@testable import RunestoneAppKit
import XCTest

@MainActor
final class FoldingRenderingTests: XCTestCase {
    func testTranslucentChevronPreservesLineNumberOpacity() throws {
        let opaque = try darkestChevronPixel(color: .black)
        let translucent = try darkestChevronPixel(color: NSColor.black.withAlphaComponent(0.3))
        XCTAssertEqual(translucent, 1 - (1 - opaque) * 0.3, accuracy: 0.01)
    }

    private func darkestChevronPixel(color: NSColor) throws -> CGFloat {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 64, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0))
        let graphics = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 64, height: 64).fill()
        SyntaxFoldIndicator.draw(at: CGPoint(x: 32, y: 32), collapsed: false,
                                 color: color, in: graphics.cgContext)
        NSGraphicsContext.restoreGraphicsState()
        return (0..<64).flatMap { y in
            (0..<64).compactMap { x in bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB)?.redComponent }
        }.min() ?? 1
    }
}
#endif
