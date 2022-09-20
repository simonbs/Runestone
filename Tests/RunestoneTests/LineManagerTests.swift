@testable import Runestone
import XCTest

final class LineManagerTests: XCTestCase {
    func testLineLength() {
        let tree = DocumentLineTree(minimumValue: 0, rootValue: 0, rootData: .init(lineHeight: 0))
        let firstLine = tree.node(containingLocation: 0)
        firstLine?.data.totalLength = 6
        firstLine?.data.delimiterLength = 1
        XCTAssertEqual(firstLine?.data.length, 5)
        firstLine?.data.delimiterLength = 2
        XCTAssertEqual(firstLine?.data.length, 4)
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
