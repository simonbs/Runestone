@testable import Runestone
import TestTreeSitterLanguages
import XCTest

final class HTMLIndentationTests: XCTestCase {
    func testInsertingLineBreakInElements() {
        // <div>|</div>
        let text = "<div></div>"
        let languageMode = LanguageModeFactory.htmlLanguageMode(text: text)
        let caretPosition = LinePosition(row: 0, column: 5)
        let strategy = languageMode.strategyForInsertingLineBreak(from: caretPosition, to: caretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 1)
        XCTAssertTrue(strategy.insertExtraLineBreak)
    }

    func testInsertingLineBreakInElementsWithCharactersSelected() {
        // <div>|hello world|</div>
        let text = "<div>hello world</div>"
        let languageMode = LanguageModeFactory.htmlLanguageMode(text: text)
        let startCaretPosition = LinePosition(row: 0, column: 5)
        let endCaretPosition = LinePosition(row: 0, column: 16)
        let strategy = languageMode.strategyForInsertingLineBreak(from: startCaretPosition, to: endCaretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 1)
        XCTAssertTrue(strategy.insertExtraLineBreak)
    }

    func testInsertingLineBreakInElementsWithCharactersSelectedContainingLineBreak() {
        // <div>|
        //   hello world
        // |</div>
        let text = "<div>\n  hello world\n</div>"
        let languageMode = LanguageModeFactory.htmlLanguageMode(text: text)
        let startCaretPosition = LinePosition(row: 0, column: 5)
        let endCaretPosition = LinePosition(row: 2, column: 0)
        let strategy = languageMode.strategyForInsertingLineBreak(from: startCaretPosition, to: endCaretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 1)
        XCTAssertTrue(strategy.insertExtraLineBreak)
    }
}
