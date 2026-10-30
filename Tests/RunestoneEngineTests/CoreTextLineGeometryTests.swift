import CoreText
@testable import RunestoneEngine
import XCTest

final class CoreTextLineGeometryTests: XCTestCase {
    func testMixedDirectionSegmentsAreClippedToVisibleRange() throws {
        let string = "ABC אבגד DEF" as NSString
        let text = NSAttributedString(string: string as String, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Menlo" as CFString, 20, nil)
        ])
        let line = CTLineCreateWithAttributedString(text)
        let wordRange = string.range(of: "אבגד")
        let geometry = CoreTextLineGeometry(line: line, visibleRange: wordRange)
        let runs = try XCTUnwrap(CTLineGetGlyphRuns(line) as? [CTRun])
        let rtlRun = try XCTUnwrap(runs.first { CTRunGetStatus($0).contains(.rightToLeft) })
        let expected = try XCTUnwrap(CoreTextRunGeometry.horizontalBounds(of: rtlRun))
        let segments = geometry.horizontalSegments(for: NSRange(location: 0, length: string.length))
        let segment = try XCTUnwrap(segments.first)
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segment.lowerBound, expected.lowerBound, accuracy: 0.01)
        XCTAssertEqual(segment.upperBound, expected.upperBound, accuracy: 0.01)
        XCTAssertTrue(geometry.horizontalSegments(for: NSRange(location: 0, length: 3)).isEmpty)
        let visible = geometry.visibleCharacterRanges(in: expected)
        XCTAssertFalse(visible.isEmpty)
        XCTAssertTrue(visible.allSatisfy { NSIntersectionRange($0, wordRange) == $0 })
    }
}
