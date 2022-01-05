@testable import Runestone
import TestTreeSitterLanguages
import XCTest

final class JSONIndentationTests: XCTestCase {
    func testInsertingLineBreakInObject() {
        // {
        //   "hello": "world",|}
        let text = "{\n  \"hello\": \"world\",|}"
        let languageMode = LanguageModeFactory.jsonLanguageMode(text: text)
        let caretPosition = LinePosition(row: 1, column: 16)
        let strategy = languageMode.strategyForInsertingLineBreak(from: caretPosition, to: caretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 1)
        XCTAssertFalse(strategy.insertExtraLineBreak)
    }

    func testInsertingLineBreakInNestedObject() {
        // {
        //   "hello": "world",
        //   "foo": {|}}
        let text = "{\n  \"hello\": \"world\",\n  \"foo\": {}}"
        let languageMode = LanguageModeFactory.jsonLanguageMode(text: text)
        let caretPosition = LinePosition(row: 2, column: 10)
        let strategy = languageMode.strategyForInsertingLineBreak(from: caretPosition, to: caretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 2)
        XCTAssertTrue(strategy.insertExtraLineBreak)
    }

    func testInsertingLineBreakAfterNestedObject() {
        // {
        //   "hello": "world",
        //   "foo": {}|
        // }
        let text = "{\n  \"hello\": \"world\",\n  \"foo\": {}\n}"
        let languageMode = LanguageModeFactory.jsonLanguageMode(text: text)
        let caretPosition = LinePosition(row: 2, column: 11)
        let strategy = languageMode.strategyForInsertingLineBreak(from: caretPosition, to: caretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 1)
        XCTAssertFalse(strategy.insertExtraLineBreak)
    }

    func testInsertingLineBreakBeforeClosingBracket() {
        // Adding a line break before a closing bracket should decrease the indent level.
        // |{
        //   "hello": "world",
        //   "foo": "bar"|}
        let text = "{\n  \"hello\": \"world\",\n  \"foo\": \"bar\"}"
        let languageMode = LanguageModeFactory.jsonLanguageMode(text: text)
        let caretPosition = LinePosition(row: 2, column: 14)
        let strategy = languageMode.strategyForInsertingLineBreak(from: caretPosition, to: caretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 0)
        XCTAssertFalse(strategy.insertExtraLineBreak)
    }

    func testInsertingLineBreakAtDocumentStart() {
        // |{
        //   "hello": "world"
        // }
        let text = "{\n  \"hello\": \"world\"\n}"
        let languageMode = LanguageModeFactory.jsonLanguageMode(text: text)
        let caretPosition = LinePosition(row: 0, column: 0)
        let strategy = languageMode.strategyForInsertingLineBreak(from: caretPosition, to: caretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 0)
        XCTAssertFalse(strategy.insertExtraLineBreak)
    }

    func testInsertingLineBreakAfterTwoLinesOnSingleLine() {
        // Inserting line break in an object in an array should only increment the indent level by 1
        // if the array and the object starts on the same line.
        // [{|}]
        let text = "[{}]"
        let languageMode = LanguageModeFactory.jsonLanguageMode(text: text)
        let caretPosition = LinePosition(row: 0, column: 2)
        let strategy = languageMode.strategyForInsertingLineBreak(from: caretPosition, to: caretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 1)
        XCTAssertTrue(strategy.insertExtraLineBreak)
    }
}
