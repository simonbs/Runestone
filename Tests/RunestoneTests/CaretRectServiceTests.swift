@testable import Runestone
import XCTest

final class CaretRectServiceTests: XCTestCase {
    func testCaretAtEndOfPartiallyTypesetLine() {
        let textInputView = TextInputView(theme: DefaultTheme())
        textInputView.scrollViewWidth = 365
        textInputView.string = NSString(string: String(repeating: "a", count: 10_000))
        textInputView.layoutLines(toLocation: 0)

        let caretBeforeFullLayout = textInputView.caretRect(at: textInputView.string.length)

        textInputView.layoutLines(toLocation: textInputView.string.length)
        let caretAfterFullLayout = textInputView.caretRect(at: textInputView.string.length)
        XCTAssertEqual(caretBeforeFullLayout, caretAfterFullLayout)
        XCTAssertGreaterThan(caretBeforeFullLayout.minY, 500)
        XCTAssertGreaterThan(caretBeforeFullLayout.height, 0)
    }
}
