import XCTest
@testable import Runestone

final class LineManagerTests: XCTestCase {
    func testLineLength() {
        let tree = DocumentLineTree(minimumValue: 0, rootValue: 0, rootData: .init(lineHeight: 0))
        let firstLine = tree.node(containingLocation: 0)
        firstLine.data.totalLength = 6
        firstLine.data.delimiterLength = 1
        XCTAssertEqual(firstLine.data.length, 5)
        firstLine.data.delimiterLength = 2
        XCTAssertEqual(firstLine.data.length, 4)
    }

    func testLineDetails1() {
        let lineManager = createLineManager(containing: "hello\nworld\nwhat's up")
        // First line
        let lineDetails1 = lineManager.lineDetails(at: 3)
        XCTAssertEqual(lineDetails1?.position.row, 0)
        XCTAssertEqual(lineDetails1?.position.column, 3)
        XCTAssertEqual(lineDetails1?.startLocation, 0)
        XCTAssertEqual(lineDetails1?.totalLength, 6)
        let lineDetails2 = lineManager.lineDetails(at: 5)
        XCTAssertEqual(lineDetails2?.position.row, 0)
        XCTAssertEqual(lineDetails2?.position.column, 5)
        XCTAssertEqual(lineDetails2?.startLocation, 0)
        XCTAssertEqual(lineDetails2?.totalLength, 6)
        // Second line
        let lineDetails3 = lineManager.lineDetails(at: 6)
        XCTAssertEqual(lineDetails3?.position.row, 1)
        XCTAssertEqual(lineDetails3?.position.column, 0)
        XCTAssertEqual(lineDetails3?.startLocation, 6)
        XCTAssertEqual(lineDetails3?.totalLength, 6)
        let lineDetails4 = lineManager.lineDetails(at: 7)
        XCTAssertEqual(lineDetails4?.position.row, 1)
        XCTAssertEqual(lineDetails4?.position.column, 1)
        XCTAssertEqual(lineDetails4?.startLocation, 6)
        XCTAssertEqual(lineDetails4?.totalLength, 6)
        // Third line
        let lineDetails5 = lineManager.lineDetails(at: 17)
        XCTAssertEqual(lineDetails5?.position.row, 2)
        XCTAssertEqual(lineDetails5?.position.column, 5)
        XCTAssertEqual(lineDetails5?.startLocation, 12)
        XCTAssertEqual(lineDetails5?.totalLength, 9)
        let lineDetails6 = lineManager.lineDetails(at: 21)
        XCTAssertEqual(lineDetails6?.position.row, 2)
        XCTAssertEqual(lineDetails6?.position.column, 9)
        XCTAssertEqual(lineDetails6?.startLocation, 12)
        XCTAssertEqual(lineDetails6?.totalLength, 9)
        // Out of bounds
        let linePosition7 = lineManager.lineDetails(at: -1)
        let linePosition8 = lineManager.lineDetails(at: 22)
        XCTAssertNil(linePosition7)
        XCTAssertNil(linePosition8)
    }
}

private extension LineManagerTests {
    private func createLineManager(containing string: String) -> LineManager {
        let stringView = StringView(string: string)
        let lineManager = LineManager(stringView: stringView)
        lineManager.insert(string as NSString, at: 0)
        return lineManager
    }
}
