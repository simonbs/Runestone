@testable import Runestone
import TestTreeSitterLanguages
import XCTest

final class YAMLIndentationTests: XCTestCase {
    func testInsertingLineBreakAfterKey() {
        // helloWorld:|
        let text = "helloWorld:"
        let languageMode = LanguageModeFactory.yamlLanguageMode(text: text)
        let caretPosition = LinePosition(row: 0, column: 11)
        let strategy = languageMode.strategyForInsertingLineBreak(from: caretPosition, to: caretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 1)
        XCTAssertFalse(strategy.insertExtraLineBreak)
    }

    func testInsertingLineBreakAfterNestedKey() {
        // helloWorld:
        //   howAreYou:|
        let text = "helloWorld:\n  howAreYou:"
        let languageMode = LanguageModeFactory.yamlLanguageMode(text: text)
        let caretPosition = LinePosition(row: 1, column: 12)
        let strategy = languageMode.strategyForInsertingLineBreak(from: caretPosition, to: caretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 2)
        XCTAssertFalse(strategy.insertExtraLineBreak)
    }
}
