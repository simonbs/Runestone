import CoreText
@testable import Runestone
import UIKit
import XCTest

final class LineFragmentSpellingTests: XCTestCase {
    func testHorizontalViewportSkipsHiddenPrefixOfLongLine() throws {
        let prefix = String(repeating: "word ", count: 4_000)
        let string = prefix + "mispelled " + prefix
        let wordRange = (string as NSString).range(of: "mispelled")
        let renderer = renderer(string: string, range: NSRange(location: 0, length: (string as NSString).length))
        let wordStart = width(of: prefix)
        let wordEnd = wordStart + width(of: "mispelled")

        let ranges = renderer.visibleCharacterRanges(in: (wordStart - 8) ... (wordEnd + 8))
        let range = try XCTUnwrap(ranges.first)

        XCTAssertEqual(ranges.count, 1)
        XCTAssertLessThan(range.length, 30)
        XCTAssertGreaterThan(range.location, 19_990)
        XCTAssertEqual(NSIntersectionRange(range, wordRange), wordRange)
    }

    func testSpellingRangeSplitsAcrossWrappedFragmentsAfterEmoji() throws {
        let string = "😀 mispelled"
        let wordRange = (string as NSString).range(of: "mispelled")
        let first = renderer(string: string, range: NSRange(location: 0, length: 7))
        let second = renderer(string: string, range: NSRange(location: 7, length: 5))

        let firstSegment = try XCTUnwrap(first.spellingUnderlineSegments(in: wordRange).first)
        let secondSegment = try XCTUnwrap(second.spellingUnderlineSegments(in: wordRange).first)

        XCTAssertEqual(firstSegment.lowerBound, width(of: "😀 "), accuracy: 0.5)
        XCTAssertEqual(firstSegment.upperBound - firstSegment.lowerBound, width(of: "misp"), accuracy: 0.5)
        XCTAssertEqual(secondSegment.lowerBound, 0, accuracy: 0.5)
        XCTAssertEqual(secondSegment.upperBound, width(of: "elled"), accuracy: 0.5)
        XCTAssertTrue(second.spellingUnderlineSegments(in: NSRange(location: 0, length: 2)).isEmpty)
    }

    func testRightToLeftWordDoesNotUnderlineAdjacentLeftToRightText() throws {
        let string = "ABC אבגד DEF"
        let wordRange = (string as NSString).range(of: "אבגד")
        let renderer = renderer(string: string, range: NSRange(location: 0, length: (string as NSString).length))

        let segments = renderer.spellingUnderlineSegments(in: wordRange)
        let segment = try XCTUnwrap(segments.first)

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segment.lowerBound, width(of: "ABC "), accuracy: 0.5)
        XCTAssertEqual(segment.upperBound - segment.lowerBound, width(of: "אבגד"), accuracy: 0.5)
    }

    private func renderer(string: String, range: NSRange) -> LineFragmentRenderer {
        let attributedString = NSAttributedString(string: string, attributes: [.font: UIFont.systemFont(ofSize: 20)])
        let typesetter = CTTypesetterCreateWithAttributedString(attributedString)
        let line = CTTypesetterCreateLine(typesetter, CFRange(location: range.location, length: range.length))
        let size = CGSize(width: CTLineGetTypographicBounds(line, nil, nil, nil), height: 24)
        let fragment = LineFragment(id: LineFragmentID(lineId: "test", lineFragmentIndex: 0),
                                    index: 0,
                                    visibleRange: range,
                                    line: line,
                                    descent: 5,
                                    baseSize: size,
                                    scaledSize: size,
                                    yPosition: 0)
        return LineFragmentRenderer(lineFragment: fragment, invisibleCharacterConfiguration: InvisibleCharacterConfiguration())
    }

    private func width(of string: String) -> CGFloat {
        let attributedString = NSAttributedString(string: string, attributes: [.font: UIFont.systemFont(ofSize: 20)])
        return CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attributedString), nil, nil, nil))
    }
}
