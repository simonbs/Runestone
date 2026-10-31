#if canImport(AppKit)
import AppKit
import CoreText
import RunestoneAppKit
import RunestoneEngine
import XCTest

final class LineFragmentRendererTests: XCTestCase {
    func testWrappedFragmentsMatchCoreTextPlacementInTranslatedFlippedContext() throws {
        let input = NSAttributedString(string: "café 😀 alpha beta gamma delta", attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .regular),
            .foregroundColor: NSColor.black
        ])
        let typesetter = LineTypesetter(lineID: "line", preparation: DefaultLineTypesetterPreparation(backgroundColorKey: .backgroundColor))
        typesetter.constrainingWidth = 100
        typesetter.lineFragmentHeightMultiplier = 1.5
        typesetter.prepareToTypeset(input)
        typesetter.typeset(.toLocation(input.length))
        XCTAssertGreaterThan(typesetter.lineFragments.count, 1)
        let last = try XCTUnwrap(typesetter.lineFragments.last)
        let height = Int(ceil(last.yPosition + last.scaledSize.height)) + 20
        let width = 140
        let actual = try bitmap(width: width, height: height)
        let reference = try bitmap(width: width, height: height)
        let origin = CGPoint(x: 8, y: 8)
        for fragment in typesetter.lineFragments {
            actual.saveGState()
            actual.translateBy(x: origin.x, y: CGFloat(height) - origin.y - fragment.yPosition)
            actual.scaleBy(x: 1, y: -1)
            LineFragmentRenderer.draw(fragment, in: actual)
            actual.restoreGState()

            reference.textMatrix = .identity
            reference.textPosition = CGPoint(x: origin.x, y: CGFloat(height) - origin.y - fragment.yPosition
                                             - fragment.scaledSize.height + fragment.verticalGeometry.coreTextBaseline)
            CTLineDraw(fragment.line, reference)
        }
        let actualBytes = try bytes(actual, width: width, height: height)
        let referenceBytes = try bytes(reference, width: width, height: height)
        let pixelIndices = stride(from: 3, to: actualBytes.count, by: 4)
        let actualPixels = pixelIndices.filter { actualBytes[$0] != 0 }.count
        let referencePixels = pixelIndices.filter { referenceBytes[$0] != 0 }.count
        let overlapPixels = pixelIndices.filter { actualBytes[$0] != 0 && referenceBytes[$0] != 0 }.count
        XCTAssertGreaterThan(actualPixels, 0)
        XCTAssertGreaterThan(referencePixels, 0)
        XCTAssertGreaterThan(Double(overlapPixels) / Double(max(actualPixels, referencePixels)), 0.85,
                             "actual: \(actualPixels), reference: \(referencePixels), overlap: \(overlapPixels)")
        for fragment in typesetter.lineFragments {
            let startY = max(0, Int(origin.y + fragment.yPosition))
            let endY = min(height, Int(ceil(origin.y + fragment.yPosition + fragment.scaledSize.height)))
            let hasGlyph = (startY ..< endY).contains { y in
                (0 ..< width).contains { x in actualBytes[(y * width + x) * 4 + 3] != 0 }
            }
            XCTAssertTrue(hasGlyph, "Missing glyphs in fragment \(fragment.index)")
        }
    }

    func testBackgroundOverlayAndCallerStateSurviveDrawing() throws {
        let input = NSAttributedString(string: "abcdef", attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .regular),
            .foregroundColor: NSColor.clear,
            .backgroundColor: NSColor.red
        ])
        let typesetter = LineTypesetter(lineID: "line", preparation: DefaultLineTypesetterPreparation(backgroundColorKey: .backgroundColor))
        typesetter.constrainingWidth = 200
        typesetter.prepareToTypeset(input)
        let fragment = try XCTUnwrap(typesetter.typeset(.toLocation(input.length)).first)
        XCTAssertEqual(input.attribute(.backgroundColor, at: 0, effectiveRange: nil) as? NSColor, .red)
        let width = 160
        let height = Int(ceil(fragment.scaledSize.height)) + 8
        let context = try bitmap(width: width, height: height)
        context.textMatrix = CGAffineTransform(scaleX: 2, y: 3)
        context.textPosition = CGPoint(x: 7, y: 9)
        let originalMatrix = context.textMatrix
        let originalPosition = context.textPosition
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        let originalTransform = context.ctm
        LineFragmentRenderer.draw(fragment, in: context) { context in
            let start = CTLineGetOffsetForStringIndex(fragment.line, 3, nil)
            let end = CTLineGetOffsetForStringIndex(fragment.line, 6, nil)
            context.setFillColor(NSColor.green.cgColor)
            context.fill(CGRect(x: start, y: 0, width: end - start, height: fragment.scaledSize.height))
            context.translateBy(x: 20, y: 20)
        }
        XCTAssertEqual(context.ctm, originalTransform)
        XCTAssertEqual(context.textMatrix, originalMatrix)
        XCTAssertEqual(context.textPosition, originalPosition)
        let data = try bytes(context, width: width, height: height)
        let y = 2
        for (index, expected): (Int, [UInt8]) in [(1, [255, 0, 0, 255]), (4, [0, 255, 0, 255])] {
            let x = Int(CTLineGetOffsetForStringIndex(fragment.line, index, nil) + 2)
            let offset = (y * width + x) * 4
            XCTAssertEqual(Array(data[offset ..< offset + 4]), expected)
        }
    }

    private func bitmap(width: Int, height: Int) throws -> CGContext {
        try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
    }

    private func bytes(_ context: CGContext, width: Int, height: Int) throws -> [UInt8] {
        let data = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        return Array(UnsafeBufferPointer(start: data, count: width * height * 4))
    }
}
#endif
