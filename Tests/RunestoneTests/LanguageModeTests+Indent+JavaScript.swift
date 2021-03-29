import XCTest
@testable import Runestone
import TestTreeSitterLanguages

extension LanguageModeTests {
    func testJavaScript_insertingLineBreakBetweenBrackets() {
        let text = "function greet(name) {}"
        let languageMode = javaScriptLanguageMode(text: text)
        // function greet(name) {|}
        let caretPosition1 = LinePosition(row: 0, column: 22)
        let strategy1 = languageMode.strategyForInsertingLineBreak(from: caretPosition1, to: caretPosition1, using: .space(length: 2))
        XCTAssertEqual(strategy1.indentLevel, 1)
        XCTAssertTrue(strategy1.insertExtraLineBreak)
        // function greet(name|) {}
        let caretPosition2 = LinePosition(row: 0, column: 22)
        let strategy2 = languageMode.strategyForInsertingLineBreak(from: caretPosition2, to: caretPosition2, using: .space(length: 2))
        XCTAssertEqual(strategy2.indentLevel, 1)
        XCTAssertTrue(strategy2.insertExtraLineBreak)
    }

    func testJavaScript_insertingLineBreakBrackets() {
        let text = "function greet(name) {}"
        let languageMode = javaScriptLanguageMode(text: text)
        // function greet(name) {}|
        let caretPosition = LinePosition(row: 0, column: 23)
        let strategy = languageMode.strategyForInsertingLineBreak(from: caretPosition, to: caretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 0)
        XCTAssertFalse(strategy.insertExtraLineBreak)
    }

    func testJavaScript_insertingLineBreakAtDocumentStart() {
        let text = "function greet(name) {}"
        let languageMode = javaScriptLanguageMode(text: text)
        // |function greet(name) {}
        let caretPosition = LinePosition(row: 0, column: 0)
        let strategy = languageMode.strategyForInsertingLineBreak(from: caretPosition, to: caretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 0)
        XCTAssertFalse(strategy.insertExtraLineBreak)
    }

    func testJavaScript_insertingLineBreakInMiddleOfLine() {
        let text = "function greet(name) {}"
        let languageMode = javaScriptLanguageMode(text: text)
        // fun|ction greet(name) {}
        let caretPosition1 = LinePosition(row: 0, column: 3)
        let strategy1 = languageMode.strategyForInsertingLineBreak(from: caretPosition1, to: caretPosition1, using: .space(length: 2))
        XCTAssertEqual(strategy1.indentLevel, 0)
        XCTAssertFalse(strategy1.insertExtraLineBreak)
        // function greet|(name) {}
        let caretPosition2 = LinePosition(row: 0, column: 3)
        let strategy2 = languageMode.strategyForInsertingLineBreak(from: caretPosition2, to: caretPosition2, using: .space(length: 2))
        XCTAssertEqual(strategy2.indentLevel, 0)
        XCTAssertFalse(strategy2.insertExtraLineBreak)
        // function greet(name) |{}
        let caretPosition3 = LinePosition(row: 0, column: 19)
        let strategy3 = languageMode.strategyForInsertingLineBreak(from: caretPosition3, to: caretPosition3, using: .space(length: 2))
        XCTAssertEqual(strategy3.indentLevel, 0)
        XCTAssertFalse(strategy3.insertExtraLineBreak)
    }
}
