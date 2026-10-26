@testable import Runestone
import XCTest

final class WritingToolsPresentationTests: XCTestCase {
    func testChooserWithoutSessionForwardsPresentationOnceAndLeavesEditingUnchanged() throws {
        let view = TextView()
        view.text = "Original"
        let recorder = WritingToolsPresentationRecorder()
        view.editorDelegate = recorder
        let input = try textInput(in: view)

        // Exercise the Objective-C selectors UIKit sends to its UITextInput, without Apple Intelligence.
        input.perform(NSSelectorFromString("willPresentWritingTools"))
        input.perform(NSSelectorFromString("willPresentWritingTools"))
        XCTAssertEqual(recorder.presentedStates, [true])
        XCTAssertFalse(view.isWritingToolsActive)
        XCTAssertEqual(view.text, "Original")

        input.perform(NSSelectorFromString("didDismissWritingTools"))
        input.perform(NSSelectorFromString("didDismissWritingTools"))
        XCTAssertEqual(recorder.presentedStates, [true, false])
        XCTAssertTrue(recorder.activeStates.isEmpty)
        view.selectedRange = NSRange(location: 8, length: 0)
        view.insertText(" text")
        XCTAssertEqual(view.text, "Original text")
        XCTAssertFalse(view.isWritingToolsPresented)
        XCTAssertFalse(view.isWritingToolsActive)
    }

    func testPanelAndEditingSessionCanEndInEitherOrder() throws {
        for dismissPanelFirst in [true, false] {
            let view = TextView()
            let recorder = WritingToolsPresentationRecorder()
            view.editorDelegate = recorder
            let input = try textInput(in: view)
            input.willPresentWritingTools()
            input.setWritingToolsActive(true)

            if dismissPanelFirst {
                input.didDismissWritingTools()
                XCTAssertFalse(view.isWritingToolsPresented)
                XCTAssertTrue(view.isWritingToolsActive)
                input.setWritingToolsActive(false)
            } else {
                input.setWritingToolsActive(false)
                XCTAssertTrue(view.isWritingToolsPresented)
                XCTAssertFalse(view.isWritingToolsActive)
                input.didDismissWritingTools()
            }

            XCTAssertEqual(recorder.presentedStates, [true, false])
            XCTAssertEqual(recorder.activeStates, [true, false])
            XCTAssertFalse(view.isWritingToolsPresented)
            XCTAssertFalse(view.isWritingToolsActive)
        }
    }

    func testRemovingViewFromWindowClearsPresentedStateWithoutWaitingForUIKitDismissal() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
        let view = TextView(frame: window.bounds)
        window.addSubview(view)
        let recorder = WritingToolsPresentationRecorder()
        view.editorDelegate = recorder
        let input = try textInput(in: view)
        input.willPresentWritingTools()

        view.removeFromSuperview()

        XCTAssertFalse(view.isWritingToolsPresented)
        XCTAssertEqual(recorder.presentedStates, [true, false])
        input.didDismissWritingTools()
        XCTAssertEqual(recorder.presentedStates, [true, false])
        window.addSubview(view)
        XCTAssertFalse(view.isWritingToolsPresented)
        input.willPresentWritingTools()
        XCTAssertEqual(recorder.presentedStates, [true, false, true])
        view.removeFromSuperview()
    }

    private func textInput(in view: TextView) throws -> TextInputView {
        try XCTUnwrap(view.subviews.compactMap { $0 as? TextInputView }.first)
    }
}

private final class WritingToolsPresentationRecorder: TextViewDelegate {
    var presentedStates: [Bool] = []
    var activeStates: [Bool] = []

    func textViewWritingToolsWillPresent(_ textView: TextView) {
        presentedStates.append(textView.isWritingToolsPresented)
    }

    func textViewWritingToolsDidDismiss(_ textView: TextView) {
        presentedStates.append(textView.isWritingToolsPresented)
    }

    func textViewWritingToolsWillBegin(_ textView: TextView) {
        activeStates.append(textView.isWritingToolsActive)
    }

    func textViewWritingToolsDidEnd(_ textView: TextView) {
        activeStates.append(textView.isWritingToolsActive)
    }
}
