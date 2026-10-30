@testable import Runestone
import XCTest

final class HorizontalTextMovementTests: XCTestCase {
    func testMovementKeepsComposedCharactersAndCRLFTogether() {
        let stringView = StringView(string: "a😀e\u{301}\r\nz")
        let lineManager = LineManager(stringView: stringView)
        lineManager.rebuild()

        for (start, offset, expected) in [(1, 1, 3), (3, -1, 1), (3, 1, 5), (5, -1, 3), (5, 1, 7), (7, -1, 5)] {
            XCTAssertEqual(HorizontalTextMovement.location(from: start, offset: offset,
                                                           stringView: stringView, lineManager: lineManager), expected)
        }
    }

    func testMovementStopsAtDocumentBounds() {
        let stringView = StringView(string: "abc")
        let lineManager = LineManager(stringView: stringView)
        lineManager.rebuild()

        XCTAssertEqual(HorizontalTextMovement.location(from: 0, offset: -1,
                                                       stringView: stringView, lineManager: lineManager), 0)
        XCTAssertEqual(HorizontalTextMovement.location(from: 3, offset: 1,
                                                       stringView: stringView, lineManager: lineManager), 3)
    }

    func testMovementSkipsCollapsedLinesInBothDirections() {
        let stringView = StringView(string: "head\r\none\r\ntwo\r\ntail")
        let lineManager = LineManager(stringView: stringView)
        lineManager.rebuild()
        lineManager.setCollapsedLineRanges([1...2])
        let header = lineManager.firstLine
        let headerEnd = header.location + header.data.length
        let following = lineManager.line(atRow: 3).location

        XCTAssertEqual(HorizontalTextMovement.location(from: headerEnd, offset: 1,
                                                       stringView: stringView, lineManager: lineManager), following)
        XCTAssertEqual(HorizontalTextMovement.location(from: following, offset: -1,
                                                       stringView: stringView, lineManager: lineManager), headerEnd)
        XCTAssertTrue(lineManager.isLineHidden(1))
    }
}
