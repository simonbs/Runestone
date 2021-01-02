import XCTest
@testable import Runestone

private final class LinePositionTestCase: LineManagerDelegate {
    let lineManager = LineManager()

    private let string: NSString

    init(string: NSString) {
        self.string = string
        lineManager.delegate = self
        lineManager.insert(string, at: 0)
    }

    func lineManager(_ lineManager: LineManager, characterAtLocation location: Int) -> String {
        return string.substring(with: NSRange(location: location, length: 1))
    }
}

final class LineManagerTests: XCTestCase {
    private let linePositionTestCase1 = LinePositionTestCase(string: "hello\nworld\nwhat's up")

    func testLineLength() {
        let tree = DocumentLineTree()
        let firstLine = tree.line(containingCharacterAt: 0)
        firstLine.totalLength = 6
        firstLine.delimiterLength = 1
        XCTAssertEqual(firstLine.length, 5)
        firstLine.delimiterLength = 2
        XCTAssertEqual(firstLine.length, 4)
    }

    func testLinePosition1() {
        // First line
        let linePosition1 = linePositionTestCase1.lineManager.positionOfLine(containingCharacterAt: 3)
        XCTAssertEqual(linePosition1?.lineNumber, 0)
        XCTAssertEqual(linePosition1?.column, 3)
        XCTAssertEqual(linePosition1?.lineStartLocation, 0)
        XCTAssertEqual(linePosition1?.length, 6)
        let linePosition2 = linePositionTestCase1.lineManager.positionOfLine(containingCharacterAt: 5)
        XCTAssertEqual(linePosition2?.lineNumber, 0)
        XCTAssertEqual(linePosition2?.column, 5)
        XCTAssertEqual(linePosition2?.lineStartLocation, 0)
        XCTAssertEqual(linePosition2?.length, 6)
        // Second line
        let linePosition3 = linePositionTestCase1.lineManager.positionOfLine(containingCharacterAt: 6)
        XCTAssertEqual(linePosition3?.lineNumber, 1)
        XCTAssertEqual(linePosition3?.column, 0)
        XCTAssertEqual(linePosition3?.lineStartLocation, 6)
        XCTAssertEqual(linePosition3?.length, 6)
        let linePosition4 = linePositionTestCase1.lineManager.positionOfLine(containingCharacterAt: 7)
        XCTAssertEqual(linePosition4?.lineNumber, 1)
        XCTAssertEqual(linePosition4?.column, 1)
        XCTAssertEqual(linePosition4?.lineStartLocation, 6)
        XCTAssertEqual(linePosition4?.length, 6)
        // Third line
        let linePosition5 = linePositionTestCase1.lineManager.positionOfLine(containingCharacterAt: 17)
        XCTAssertEqual(linePosition5?.lineNumber, 2)
        XCTAssertEqual(linePosition5?.column, 5)
        XCTAssertEqual(linePosition5?.lineStartLocation, 12)
        XCTAssertEqual(linePosition5?.length, 9)
        let linePosition6 = linePositionTestCase1.lineManager.positionOfLine(containingCharacterAt: 21)
        XCTAssertEqual(linePosition6?.lineNumber, 2)
        XCTAssertEqual(linePosition6?.column, 9)
        XCTAssertEqual(linePosition6?.lineStartLocation, 12)
        XCTAssertEqual(linePosition6?.length, 9)
        // Out of bounds
        let linePosition7 = linePositionTestCase1.lineManager.positionOfLine(containingCharacterAt: -1)
        let linePosition8 = linePositionTestCase1.lineManager.positionOfLine(containingCharacterAt: 22)
        XCTAssertNil(linePosition7)
        XCTAssertNil(linePosition8)
    }
}
