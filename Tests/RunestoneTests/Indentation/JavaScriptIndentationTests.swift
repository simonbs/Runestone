@testable import Runestone
import TestTreeSitterLanguages
import XCTest

final class JavaScriptIndentationTests: XCTestCase {
    func testInsertingLineBreakBetweenBrackets() {
        let text = "function greet(name) {}"
        let languageMode = LanguageModeFactory.javaScriptLanguageMode(text: text)
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

    func testInsertingLineBreakBrackets() {
        let text = "function greet(name) {}"
        let languageMode = LanguageModeFactory.javaScriptLanguageMode(text: text)
        // function greet(name) {}|
        let caretPosition = LinePosition(row: 0, column: 23)
        let strategy = languageMode.strategyForInsertingLineBreak(from: caretPosition, to: caretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 0)
        XCTAssertFalse(strategy.insertExtraLineBreak)
    }

    func testInsertingLineBreakAtDocumentStart() {
        let text = "function greet(name) {}"
        let languageMode = LanguageModeFactory.javaScriptLanguageMode(text: text)
        // |function greet(name) {}
        let caretPosition = LinePosition(row: 0, column: 0)
        let strategy = languageMode.strategyForInsertingLineBreak(from: caretPosition, to: caretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 0)
        XCTAssertFalse(strategy.insertExtraLineBreak)
    }

    func testInsertingLineBreakInMiddleOfLine() {
        let text = "function greet(name) {}"
        let languageMode = LanguageModeFactory.javaScriptLanguageMode(text: text)
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
