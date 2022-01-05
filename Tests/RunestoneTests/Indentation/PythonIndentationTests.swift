@testable import Runestone
import TestTreeSitterLanguages
import XCTest

final class PythonIndentationTests: XCTestCase {
    func testInsertingLineBreakAfterFunction() {
        // def greet(name):|
        let text = "def greet(name):"
        let languageMode = LanguageModeFactory.pythonLanguageMode(text: text)
        let caretPosition = LinePosition(row: 0, column: 16)
        let strategy = languageMode.strategyForInsertingLineBreak(from: caretPosition, to: caretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 1)
        XCTAssertFalse(strategy.insertExtraLineBreak)
    }

    func testInsertingLineBreakAfterFunctionWithMultipleFunctions() {
        // def greet(name):
        //   return "Hello " + name
        // end
        //
        // def wave(name):|
        let text = "def greet(name):\n   return \"Hello \" + name\nend\n\ndef wave(name):"
        let languageMode = LanguageModeFactory.pythonLanguageMode(text: text)
        let caretPosition = LinePosition(row: 4, column: 14)
        let strategy = languageMode.strategyForInsertingLineBreak(from: caretPosition, to: caretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 1)
        XCTAssertFalse(strategy.insertExtraLineBreak)
    }
}
