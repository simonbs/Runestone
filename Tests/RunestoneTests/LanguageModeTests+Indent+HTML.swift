@testable import Runestone
import TestTreeSitterLanguages
import XCTest

extension LanguageModeTests {
    func testHTML_insertingLineBreakInElements() {
        // <div>|</div>
        let text = "<div></div>"
        let languageMode = htmlLanguageMode(text: text)
        let caretPosition = LinePosition(row: 0, column: 5)
        let strategy = languageMode.strategyForInsertingLineBreak(from: caretPosition, to: caretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 1)
        XCTAssertTrue(strategy.insertExtraLineBreak)
    }

    func testHTML_insertingLineBreakInElementsWithCharactersSelected() {
        // <div>|hello world|</div>
        let text = "<div>hello world</div>"
        let languageMode = htmlLanguageMode(text: text)
        let startCaretPosition = LinePosition(row: 0, column: 5)
        let endCaretPosition = LinePosition(row: 0, column: 16)
        let strategy = languageMode.strategyForInsertingLineBreak(from: startCaretPosition, to: endCaretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 1)
        XCTAssertTrue(strategy.insertExtraLineBreak)
    }

    func testHTML_insertingLineBreakInElementsWithCharactersSelectedContainingLineBreak() {
        // <div>|
        //   hello world
        // |</div>
        let text = "<div>\n  hello world\n</div>"
        let languageMode = htmlLanguageMode(text: text)
        let startCaretPosition = LinePosition(row: 0, column: 5)
        let endCaretPosition = LinePosition(row: 2, column: 0)
        let strategy = languageMode.strategyForInsertingLineBreak(from: startCaretPosition, to: endCaretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 1)
        XCTAssertTrue(strategy.insertExtraLineBreak)
    }
}
