import CoreText
@testable import Runestone
import XCTest

final class CoreTextRunGeometryTests: XCTestCase {
    func testBoundsCoverEveryGlyphIncludingNegativeAndNonmonotonicAdvances() {
        let positions = [CGPoint(x: 10, y: 0), CGPoint(x: 30, y: 0), CGPoint(x: 20, y: 0)]
        let advances = [CGSize(width: 4, height: 0), CGSize(width: -18, height: 0), CGSize(width: 2, height: 0)]
        XCTAssertEqual(CoreTextRunGeometry.horizontalBounds(positions: positions, advances: advances), 10 ... 30)
    }

    func testEmptyAndZeroWidthGlyphsHaveNoPaintableBounds() {
        XCTAssertNil(CoreTextRunGeometry.horizontalBounds(positions: [], advances: []))
        XCTAssertNil(CoreTextRunGeometry.horizontalBounds(positions: [.zero], advances: [.zero]))
    }

    func testCoreTextRunBoundsStayWithinTheirStyledSegments() throws {
        let text = NSMutableAttributedString(string: "abc def", attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): CTFontCreateWithName("Menlo" as CFString, 18, nil)
        ])
        let marker = NSAttributedString.Key("test-run-marker")
        text.addAttribute(marker, value: "first", range: NSRange(location: 0, length: 3))
        text.addAttribute(marker, value: "last", range: NSRange(location: 4, length: 3))
        let line = CTLineCreateWithAttributedString(text)
        let runs = try XCTUnwrap(CTLineGetGlyphRuns(line) as? [CTRun])
        for (name, range) in [("first", NSRange(location: 0, length: 3)), ("last", NSRange(location: 4, length: 3))] {
            let run = try XCTUnwrap(runs.first { (CTRunGetAttributes($0) as NSDictionary)[marker] as? String == name })
            let bounds = try XCTUnwrap(CoreTextRunGeometry.horizontalBounds(of: run))
            XCTAssertEqual(bounds.lowerBound, CTLineGetOffsetForStringIndex(line, range.location, nil), accuracy: 0.01)
            XCTAssertEqual(bounds.upperBound, CTLineGetOffsetForStringIndex(line, NSMaxRange(range), nil), accuracy: 0.01)
        }
    }
}
