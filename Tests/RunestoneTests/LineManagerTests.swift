import XCTest
@testable import Runestone

private final class LinePositionTestCase: LineManagerDelegate {
    let lineManager = LineManager()

    private let string: NSString

    init(string: NSString) {
        self.string = string
        lineManager.delegate = self
        var editedLines: Set<DocumentLineNode> = []
        lineManager.insert(string, at: 0, editedLines: &editedLines)
    }

    func lineManager(_ lineManager: LineManager, substringIn range: NSRange) -> String {
        return string.substring(with: range)
    }
}

final class LineManagerTests: XCTestCase {
    private let linePositionTestCase1 = LinePositionTestCase(string: "hello\nworld\nwhat's up")

    func testLineLength() {
        let tree = DocumentLineTree(minimumValue: 0, rootValue: 0, rootData: .init(frameHeight: 0))
        let firstLine = tree.node(containgLocation: 0)
        firstLine.data.totalLength = 6
        firstLine.data.delimiterLength = 1
        XCTAssertEqual(firstLine.data.length, 5)
        firstLine.data.delimiterLength = 2
        XCTAssertEqual(firstLine.data.length, 4)
    }

    func testLinePosition1() {
        // First line
        let linePosition1 = linePositionTestCase1.lineManager.linePosition(at: 3)
        XCTAssertEqual(linePosition1?.lineNumber, 0)
        XCTAssertEqual(linePosition1?.column, 3)
        XCTAssertEqual(linePosition1?.lineStartLocation, 0)
        XCTAssertEqual(linePosition1?.totalLength, 6)
        let linePosition2 = linePositionTestCase1.lineManager.linePosition(at: 5)
        XCTAssertEqual(linePosition2?.lineNumber, 0)
        XCTAssertEqual(linePosition2?.column, 5)
        XCTAssertEqual(linePosition2?.lineStartLocation, 0)
        XCTAssertEqual(linePosition2?.totalLength, 6)
        // Second line
        let linePosition3 = linePositionTestCase1.lineManager.linePosition(at: 6)
        XCTAssertEqual(linePosition3?.lineNumber, 1)
        XCTAssertEqual(linePosition3?.column, 0)
        XCTAssertEqual(linePosition3?.lineStartLocation, 6)
        XCTAssertEqual(linePosition3?.totalLength, 6)
        let linePosition4 = linePositionTestCase1.lineManager.linePosition(at: 7)
        XCTAssertEqual(linePosition4?.lineNumber, 1)
        XCTAssertEqual(linePosition4?.column, 1)
        XCTAssertEqual(linePosition4?.lineStartLocation, 6)
        XCTAssertEqual(linePosition4?.totalLength, 6)
        // Third line
        let linePosition5 = linePositionTestCase1.lineManager.linePosition(at: 17)
        XCTAssertEqual(linePosition5?.lineNumber, 2)
        XCTAssertEqual(linePosition5?.column, 5)
        XCTAssertEqual(linePosition5?.lineStartLocation, 12)
        XCTAssertEqual(linePosition5?.totalLength, 9)
        let linePosition6 = linePositionTestCase1.lineManager.linePosition(at: 21)
        XCTAssertEqual(linePosition6?.lineNumber, 2)
        XCTAssertEqual(linePosition6?.column, 9)
        XCTAssertEqual(linePosition6?.lineStartLocation, 12)
        XCTAssertEqual(linePosition6?.totalLength, 9)
        // Out of bounds
        let linePosition7 = linePositionTestCase1.lineManager.linePosition(at: -1)
        let linePosition8 = linePositionTestCase1.lineManager.linePosition(at: 22)
        XCTAssertNil(linePosition7)
        XCTAssertNil(linePosition8)
    }
}
