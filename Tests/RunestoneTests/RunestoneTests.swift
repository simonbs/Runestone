import XCTest
@testable import Runestone

final class RunestoneTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Runestone().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
