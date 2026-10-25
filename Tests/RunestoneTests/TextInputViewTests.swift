@testable import Runestone
import XCTest

final class TextInputViewTests: XCTestCase {
    func testReplacingTextReleasesPreviousLineControllers() {
        let textInputView = TextInputView(theme: DefaultTheme())
        textInputView.scrollViewWidth = 365
        textInputView.string = "first line\nsecond line"
        textInputView.layoutLines(toLocation: textInputView.string.length)
        weak var previousFirstLine = textInputView.lineManager.firstLine
        weak var previousLastLine = textInputView.lineManager.lastLine
        XCTAssertNotNil(previousFirstLine)
        XCTAssertNotNil(previousLastLine)

        textInputView.string = "replacement"

        XCTAssertNil(previousFirstLine)
        XCTAssertNil(previousLastLine)
        XCTAssertEqual(textInputView.string, "replacement")
        XCTAssertEqual(textInputView.lineManager.lineCount, 1)
    }
}
