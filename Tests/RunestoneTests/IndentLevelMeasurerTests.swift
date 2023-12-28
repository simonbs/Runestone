//@testable import Runestone
//import _TestTreeSitterLanguages
//import XCTest
//
//final class IndentLevelMeasurerTests: XCTestCase {
//    func testCurrentIndentTabLength2() {
//        // if (foo == "bar") {
//        //   if (hello == "world") {
//        //     console.log("Hi")
//        //   }
//        // }
//        let text = "if (foo == \"bar\") {\n  if (hello == \"world\") {\n    console.log(\"Hi\")\n  }\n}"
//        let stringView = StringView(string: text)
//        let measurer = IndentLevelMeasurer(stringView: stringView, indentLengthInSpaces: 2)
//        let indentLevelLine1 = measurer.indentLevel(ofLineStartingAt: 0, ofLength: 20)
//        XCTAssertEqual(indentLevelLine1, 0)
//        let indentLevelLine2 = measurer.indentLevel(ofLineStartingAt: 20, ofLength: 26)
//        XCTAssertEqual(indentLevelLine2, 1)
//        let indentLevelLine3 = measurer.indentLevel(ofLineStartingAt: 46, ofLength: 22)
//        XCTAssertEqual(indentLevelLine3, 2)
//        let indentLevelLine4 = measurer.indentLevel(ofLineStartingAt: 68, ofLength: 4)
//        XCTAssertEqual(indentLevelLine4, 1)
//        let indentLevelLine5 = measurer.indentLevel(ofLineStartingAt: 72, ofLength: 1)
//        XCTAssertEqual(indentLevelLine5, 0)
//    }
//
//    func testCurrentIndentTabLength4() {
//        // if (foo == "bar") {
//        //     if (hello == "world") {
//        //         console.log("Hi")
//        //     }
//        // }
//        let text = "if (foo == \"bar\") {\n    if (hello == \"world\") {\n        console.log(\"Hi\")\n    }\n}"
//        let stringView = StringView(string: text)
//        let measurer = IndentLevelMeasurer(stringView: stringView, indentLengthInSpaces: 4)
//        let indentLevelLine1 = measurer.indentLevel(ofLineStartingAt: 0, ofLength: 20)
//        XCTAssertEqual(indentLevelLine1, 0)
//        let indentLevelLine2 = measurer.indentLevel(ofLineStartingAt: 20, ofLength: 28)
//        XCTAssertEqual(indentLevelLine2, 1)
//        let indentLevelLine3 = measurer.indentLevel(ofLineStartingAt: 48, ofLength: 26)
//        XCTAssertEqual(indentLevelLine3, 2)
//        let indentLevelLine4 = measurer.indentLevel(ofLineStartingAt: 74, ofLength: 6)
//        XCTAssertEqual(indentLevelLine4, 1)
//        let indentLevelLine5 = measurer.indentLevel(ofLineStartingAt: 80, ofLength: 1)
//        XCTAssertEqual(indentLevelLine5, 0)
//    }
//}
