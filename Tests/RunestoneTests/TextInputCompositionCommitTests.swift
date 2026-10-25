@testable import Runestone
import XCTest

final class TextInputCompositionCommitTests: XCTestCase {
    func testUnmarkingNotifiesDelegateAfterCompositionEnds() throws {
        let textView = TextView()
        textView.selectedRange = NSRange(location: 0, length: 0)
        let recorder = CompositionCommitRecorder()
        textView.editorDelegate = recorder
        let input = try XCTUnwrap(textView.subviews.compactMap { $0 as? TextInputView }.first)

        input.setMarkedText("你好", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertEqual(recorder.markedStates, [true])
        input.unmarkText()

        XCTAssertEqual(recorder.markedStates, [true, false])
        XCTAssertEqual(textView.text, "你好")
        XCTAssertNil(textView.markedTextRange)
        XCTAssertEqual(textView.selectedRange, NSRange(location: 2, length: 0))
        input.unmarkText()
        XCTAssertEqual(recorder.markedStates, [true, false])
    }
}

private final class CompositionCommitRecorder: TextViewDelegate {
    var markedStates: [Bool] = []

    func textViewDidChange(_ textView: TextView) {
        markedStates.append(textView.markedTextRange != nil)
    }
}
