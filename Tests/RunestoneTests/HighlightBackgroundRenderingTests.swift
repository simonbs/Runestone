import CoreText
@testable import Runestone
import UIKit
import XCTest

final class HighlightBackgroundRenderingTests: XCTestCase {
    func testTokenBackgroundPaintsWrappedMixedDirectionTextAndComposedCharacters() throws {
        let text = "previous line abc אבג cafe\u{301} 😀 tail" as NSString
        let attributed = NSMutableAttributedString(string: text as String, attributes: [
            .font: UIFont.monospacedSystemFont(ofSize: 18, weight: .regular),
            .foregroundColor: UIColor.clear
        ])
        for word in ["אבג", "cafe\u{301}", "😀"] {
            attributed.addAttribute(.backgroundColor, value: UIColor.red, range: text.range(of: word))
        }
        let fragments = makeFragments(attributed, width: 220)
        XCTAssertGreaterThan(fragments.count, 1)
        var checkedWords: Set<String> = []
        for fragment in fragments {
            let renderer = LineFragmentRenderer(lineFragment: fragment, invisibleCharacterConfiguration: .init())
            let bitmap = try draw(renderer)
            // Sample interiors, away from run edges and antialiasing. Offsets remain
            // relative to the original string in subsequent wrapped fragments.
            for word in ["אבג", "cafe\u{301}", "😀", "abc", "tail"] {
                let range = text.range(of: word)
                guard range.location >= fragment.visibleRange.location,
                      range.upperBound <= fragment.visibleRange.upperBound else {
                    continue
                }
                let first = CTLineGetOffsetForStringIndex(fragment.line, range.location, nil)
                let last = CTLineGetOffsetForStringIndex(fragment.line, range.upperBound, nil)
                let expected: [UInt8] = ["abc", "tail"].contains(word) ? [255, 255, 255, 255] : [255, 0, 0, 255]
                XCTAssertEqual(bitmap.pixel(x: Int((first + last) / 2), y: 2), expected, word)
                checkedWords.insert(word)
            }
            XCTAssertEqual(bitmap.pixel(x: Int(ceil(fragment.baseSize.width)) + 3, y: 2), [255, 255, 255, 255])
        }
        XCTAssertEqual(checkedWords, ["אבג", "cafe\u{301}", "😀", "abc", "tail"])
    }

    func testSearchAndMarkedHighlightsPaintAboveTokenBackground() throws {
        let attributed = NSAttributedString(string: "abcdef", attributes: [
            .font: UIFont.monospacedSystemFont(ofSize: 18, weight: .regular),
            .foregroundColor: UIColor.clear,
            .backgroundColor: UIColor.red
        ])
        let fragment = try XCTUnwrap(makeFragments(attributed, width: 500).first)
        let renderer = LineFragmentRenderer(lineFragment: fragment, invisibleCharacterConfiguration: .init())
        renderer.highlightedRangeFragments = [HighlightedRangeFragment(range: NSRange(location: 2, length: 2),
                                                                       containsStart: true, containsEnd: true,
                                                                       color: .green, cornerRadius: 0)]
        renderer.markedRange = NSRange(location: 4, length: 2)
        renderer.markedTextBackgroundColor = .blue
        let bitmap = try draw(renderer)
        for (index, expected): (Int, [UInt8]) in [(1, [255, 0, 0, 255]), (3, [0, 255, 0, 255]), (5, [0, 0, 255, 255])] {
            let x = CTLineGetOffsetForStringIndex(fragment.line, index, nil) + 2
            XCTAssertEqual(bitmap.pixel(x: Int(x), y: 2), expected)
        }
    }

    func testSpellingUnderlinesRemainVisibleOverTokenBackground() throws {
        let attributed = NSAttributedString(string: "mispelled", attributes: [
            .font: UIFont.monospacedSystemFont(ofSize: 18, weight: .regular),
            .foregroundColor: UIColor.clear,
            .backgroundColor: UIColor.yellow
        ])
        let fragment = try XCTUnwrap(makeFragments(attributed, width: 500).first)
        let renderer = LineFragmentRenderer(lineFragment: fragment, invisibleCharacterConfiguration: .init())
        renderer.misspelledRanges = [NSRange(location: 0, length: attributed.length)]
        let bitmap = try draw(renderer)
        // At 1x the narrow dotted stroke blends with yellow; require a visible
        // red-dominant pixel rather than an unblended system-red pixel.
        let hasUnderline = stride(from: 0, to: bitmap.bytes.count, by: 4).contains { offset in
            let red = Int(bitmap.bytes[offset])
            return red > 200 && red - Int(bitmap.bytes[offset + 1]) > 64 && red - Int(bitmap.bytes[offset + 2]) > 64
        }
        XCTAssertTrue(hasUnderline, "The spelling underline must paint above the opaque token background.")
    }

    func testHighlightForegroundOverrideRecolorsOnlyConfiguredText() throws {
        let sourceColor = UIColor(red: 1, green: 0, blue: 0, alpha: 1)
        let overrideColor = UIColor(red: 0, green: 0, blue: 1, alpha: 1)
        let attributed = NSAttributedString(string: "abcdef", attributes: [
            .font: UIFont.monospacedSystemFont(ofSize: 24, weight: .regular),
            .foregroundColor: sourceColor
        ])
        let fragment = try XCTUnwrap(makeFragments(attributed, width: 500).first)
        let renderer = LineFragmentRenderer(lineFragment: fragment, invisibleCharacterConfiguration: .init())
        renderer.highlightedRangeFragments = [
            HighlightedRangeFragment(range: NSRange(location: 0, length: 3), containsStart: true,
                                     containsEnd: true, color: .yellow,
                                     foregroundColor: overrideColor, cornerRadius: 0),
            HighlightedRangeFragment(range: NSRange(location: 3, length: 3), containsStart: true,
                                     containsEnd: true, color: .yellow, cornerRadius: 0)
        ]

        let bitmap = try draw(renderer)
        let overrideEnd = Int(CTLineGetOffsetForStringIndex(fragment.line, 3, nil))
        XCTAssertTrue(bitmap.containsDominantColor(overrideColor, inXRange: 0 ..< overrideEnd))
        XCTAssertTrue(bitmap.containsDominantColor(sourceColor, inXRange: overrideEnd ..< bitmap.width))
    }

    private func makeFragments(_ string: NSAttributedString, width: CGFloat) -> [LineFragment] {
        let typesetter = LineTypesetter(lineID: "test")
        typesetter.constrainingWidth = width
        typesetter.prepareToTypeset(string)
        return typesetter.typesetLineFragments(toLocation: string.length)
    }

    private func draw(_ renderer: LineFragmentRenderer) throws -> Bitmap {
        let width = Int(ceil(renderer.lineFragment.baseSize.width)) + 8
        let height = Int(ceil(renderer.lineFragment.scaledSize.height))
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                              bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        renderer.draw(to: context, inCanvasOfSize: CGSize(width: width, height: height))
        let data = try XCTUnwrap(context.data)
        let bytes = Array(UnsafeBufferPointer(start: data.assumingMemoryBound(to: UInt8.self), count: width * height * 4))
        return Bitmap(bytes: bytes, width: width, height: height)
    }
}

private struct Bitmap {
    let bytes: [UInt8]
    let width: Int
    let height: Int

    func pixel(x: Int, y: Int) -> [UInt8] {
        guard (0 ..< width).contains(x), (0 ..< height).contains(y) else {
            return []
        }
        let offset = ((height - 1 - y) * width + x) * 4
        return Array(bytes[offset ..< offset + 4])
    }

    func containsDominantColor(_ color: UIColor, inXRange xRange: Range<Int>) -> Bool {
        var targetRed: CGFloat = 0
        var targetGreen: CGFloat = 0
        var targetBlue: CGFloat = 0
        color.getRed(&targetRed, green: &targetGreen, blue: &targetBlue, alpha: nil)
        let range = max(0, xRange.lowerBound) ..< min(width, xRange.upperBound)
        return range.contains { x in
            (0 ..< height).contains { y in
                let value = pixel(x: x, y: y)
                let target = [targetRed, targetGreen, targetBlue]
                let channels = value.prefix(3).map { CGFloat($0) / 255 }
                return zip(target, channels).allSatisfy { expected, actual in
                    expected < 0.1 ? actual < 0.3 : actual > 0.7
                }
            }
        }
    }

}
