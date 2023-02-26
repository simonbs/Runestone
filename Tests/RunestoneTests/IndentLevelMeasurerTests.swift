@testable import Runestone
import TestTreeSitterLanguages
import XCTest

final class IndentLevelMeasurerTests: XCTestCase {
    func testCurrentIndentTabLength2() {
        // if (foo == "bar") {
        //   if (hello == "world") {
        //     console.log("Hi")
        //   }
        // }
        let text = "if (foo == \"bar\") {\n  if (hello == \"world\") {\n    console.log(\"Hi\")\n  }\n}"
        let stringView = StringView(string: text)
        let measurer = IndentLevelMeasurer(stringView: stringView)
        let indentLevelLine1 = measurer.indentLevel(lineStartLocation: 0, lineTotalLength: 20, tabLength: 2)
        XCTAssertEqual(indentLevelLine1, 0)
        let indentLevelLine2 = measurer.indentLevel(lineStartLocation: 20, lineTotalLength: 26, tabLength: 2)
        XCTAssertEqual(indentLevelLine2, 1)
        let indentLevelLine3 = measurer.indentLevel(lineStartLocation: 46, lineTotalLength: 22, tabLength: 2)
        XCTAssertEqual(indentLevelLine3, 2)
        let indentLevelLine4 = measurer.indentLevel(lineStartLocation: 68, lineTotalLength: 4, tabLength: 2)
        XCTAssertEqual(indentLevelLine4, 1)
        let indentLevelLine5 = measurer.indentLevel(lineStartLocation: 72, lineTotalLength: 1, tabLength: 2)
        XCTAssertEqual(indentLevelLine5, 0)
    }

    func testCurrentIndentTabLength4() {
        // if (foo == "bar") {
        //     if (hello == "world") {
        //         console.log("Hi")
        //     }
        // }
        let text = "if (foo == \"bar\") {\n    if (hello == \"world\") {\n        console.log(\"Hi\")\n    }\n}"
        let stringView = StringView(string: text)
        let measurer = IndentLevelMeasurer(stringView: stringView)
        let indentLevelLine1 = measurer.indentLevel(lineStartLocation: 0, lineTotalLength: 20, tabLength: 4)
        XCTAssertEqual(indentLevelLine1, 0)
        let indentLevelLine2 = measurer.indentLevel(lineStartLocation: 20, lineTotalLength: 28, tabLength: 4)
        XCTAssertEqual(indentLevelLine2, 1)
        let indentLevelLine3 = measurer.indentLevel(lineStartLocation: 48, lineTotalLength: 26, tabLength: 4)
        XCTAssertEqual(indentLevelLine3, 2)
        let indentLevelLine4 = measurer.indentLevel(lineStartLocation: 74, lineTotalLength: 6, tabLength: 4)
        XCTAssertEqual(indentLevelLine4, 1)
        let indentLevelLine5 = measurer.indentLevel(lineStartLocation: 80, lineTotalLength: 1, tabLength: 4)
        XCTAssertEqual(indentLevelLine5, 0)
    }
}
