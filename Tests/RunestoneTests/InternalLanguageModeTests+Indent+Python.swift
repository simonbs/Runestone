@testable import Runestone
import TestTreeSitterLanguages
import XCTest

extension InternalLanguageModeTests {
    func testPython_insertingLineBreakAfterFunction() {
        // def greet(name):|
        let text = "def greet(name):"
        let languageMode = pythonLanguageMode(text: text)
        let caretPosition = LinePosition(row: 0, column: 16)
        let strategy = languageMode.strategyForInsertingLineBreak(from: caretPosition, to: caretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 1)
        XCTAssertFalse(strategy.insertExtraLineBreak)
    }

    func testPython_insertingLineBreakAfterFunctionWithMultipleFunctions() {
        // def greet(name):
        //   return "Hello " + name
        // end
        //
        // def wave(name):|
        let text = "def greet(name):\n   return \"Hello \" + name\nend\n\ndef wave(name):"
        let languageMode = pythonLanguageMode(text: text)
        let caretPosition = LinePosition(row: 4, column: 14)
        let strategy = languageMode.strategyForInsertingLineBreak(from: caretPosition, to: caretPosition, using: .space(length: 2))
        XCTAssertEqual(strategy.indentLevel, 1)
        XCTAssertFalse(strategy.insertExtraLineBreak)
    }
}
