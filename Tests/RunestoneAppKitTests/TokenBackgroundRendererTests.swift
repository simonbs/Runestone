#if canImport(AppKit)
import AppKit
import CoreText
import RunestoneAppKit
import RunestoneEngine
import XCTest

final class TokenBackgroundRendererTests: XCTestCase {
    func testPreparationPreservesInputAndDrawingPlacesOverlaysAboveTokenBackground() throws {
        let input = NSAttributedString(string: "abcdef", attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .regular),
            .foregroundColor: NSColor.clear,
            .backgroundColor: NSColor.red
        ])
        let prepared = TokenBackgroundRenderer.stringForTypesetting(input)
        XCTAssertEqual(input.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor, .red)
        XCTAssertNil(input.attribute(TokenBackgroundMapping.attributeKey, at: 0, effectiveRange: nil))
        XCTAssertNil(prepared.attribute(.backgroundColor, at: 0, effectiveRange: nil))
        XCTAssertEqual(prepared.attribute(TokenBackgroundMapping.attributeKey, at: 0, effectiveRange: nil) as? NSColor, .red)

        let line = CTLineCreateWithAttributedString(prepared)
        let width = Int(ceil(CTLineGetTypographicBounds(line, nil, nil, nil))) + 8
        let height = 24
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                              bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        func rect(_ start: Int, _ end: Int) -> CGRect {
            let x = CTLineGetOffsetForStringIndex(line, start, nil)
            let endX = CTLineGetOffsetForStringIndex(line, end, nil)
            return CGRect(x: x, y: 0, width: endX - x, height: CGFloat(height))
        }
        var passes: [String] = []
        TokenBackgroundRenderer.draw(line: line, height: CGFloat(height), in: context, drawOverlays: { context in
            passes.append("overlays")
            context.setFillColor(NSColor.green.cgColor)
            context.fill(rect(2, 6))
            context.setFillColor(NSColor.blue.cgColor)
            context.fill(rect(4, 6))
        }, drawText: { context in
            passes.append("text")
            context.textPosition = CGPoint(x: 0, y: 5)
            CTLineDraw(line, context)
        })
        XCTAssertEqual(passes, ["overlays", "text"])
        let data = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        for (index, expected): (Int, [UInt8]) in [(1, [255, 0, 0, 255]), (3, [0, 255, 0, 255]), (5, [0, 0, 255, 255])] {
            let x = Int(CTLineGetOffsetForStringIndex(line, index, nil) + 2)
            let offset = (2 * width + x) * 4
            XCTAssertEqual(Array(UnsafeBufferPointer(start: data + offset, count: 4)), expected)
        }
    }
}
#endif
