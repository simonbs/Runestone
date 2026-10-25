@testable import Runestone
import XCTest

final class TextInputTextRangeTests: XCTestCase {
    func testEmptyTextRangeReturnsEmptyString() {
        let textInputView = TextInputView(theme: DefaultTheme())
        XCTAssertEqual(textInputView.text(in: IndexedRange(location: 0, length: 0)), "")
        textInputView.insertText("Hello 🥳")
        for location in [0, 5, textInputView.string.length] {
            XCTAssertEqual(textInputView.text(in: IndexedRange(location: location, length: 0)), "")
        }
        textInputView.insertText("\n")
        XCTAssertEqual(textInputView.text(in: IndexedRange(location: textInputView.string.length, length: 0)), "")
    }

    func testNonemptyAndInvalidTextRanges() {
        let textInputView = TextInputView(theme: DefaultTheme())
        textInputView.insertText("Hello 🥳")
        XCTAssertEqual(textInputView.text(in: IndexedRange(location: 6, length: 2)), "🥳")
        XCTAssertNil(textInputView.text(in: IndexedRange(location: -1, length: 0)))
        XCTAssertNil(textInputView.text(in: IndexedRange(location: 9, length: 0)))
        XCTAssertNil(textInputView.text(in: IndexedRange(location: 6, length: 3)))
    }
}
