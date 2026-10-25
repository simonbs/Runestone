@testable import Runestone
import XCTest

final class TextInputLineEndingTests: XCTestCase {
    func testInsertionPreservesLinesWhenConvertingLineEndings() {
        let lineEndings: [LineEnding] = [.lf, .cr, .crlf]
        for sourceEnding in lineEndings {
            for destinationEnding in lineEndings {
                let textInputView = TextInputView(theme: DefaultTheme())
                textInputView.lineEndings = destinationEnding
                let lines = ["First 🥳", "", "Last", ""]
                textInputView.insertText(lines.joined(separator: sourceEnding.symbol))
                let expectedText = lines.joined(separator: destinationEnding.symbol)
                XCTAssertEqual(textInputView.string as String, expectedText)
                XCTAssertEqual(textInputView.selectedRange, NSRange(location: expectedText.utf16.count, length: 0))
            }
        }
    }

    func testInsertionConvertsMixedLineEndingsWithoutAddingLines() {
        let textInputView = TextInputView(theme: DefaultTheme())
        textInputView.lineEndings = .crlf
        textInputView.insertText("First\r\nSecond\rThird\n\nLast\r\n")
        XCTAssertEqual(textInputView.string as String, "First\r\nSecond\r\nThird\r\n\r\nLast\r\n")
    }
}
