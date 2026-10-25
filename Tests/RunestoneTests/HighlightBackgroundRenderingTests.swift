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
}
