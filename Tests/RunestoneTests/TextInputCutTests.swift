@testable import Runestone
import XCTest

final class TextInputCutTests: XCTestCase {
    func testCutNotifiesInputDelegateAroundSelectionChangeAndCanBeUndone() throws {
        let originalPasteboardItems = UIPasteboard.general.items
        defer { UIPasteboard.general.items = originalPasteboardItems }

        let view = TextInputView(theme: DefaultTheme())
        let originalText = "before 👋 after"
        let selectedText = "👋 "
        let originalSelection = (originalText as NSString).range(of: selectedText)
        let collapsedSelection = NSRange(location: originalSelection.location, length: 0)
        view.string = originalText as NSString
        view.selectedRange = originalSelection
        let recorder = CutSelectionRecorder()
        view.inputDelegate = recorder

        view.cut(nil)

        XCTAssertEqual(recorder.changes, [
            .init(phase: .willChange, text: originalText, selection: originalSelection),
            .init(phase: .didChange, text: "before after", selection: collapsedSelection)
        ])
        XCTAssertEqual(UIPasteboard.general.string, selectedText)
        XCTAssertEqual(view.string, "before after")
        XCTAssertEqual(view.selectedRange, collapsedSelection)

        let undoManager = try XCTUnwrap(view.undoManager)
        XCTAssertTrue(undoManager.canUndo)
        undoManager.undo()
        XCTAssertEqual(view.string, originalText as NSString)
        XCTAssertEqual(view.selectedRange, originalSelection)
        XCTAssertTrue(undoManager.canRedo)
        undoManager.redo()
        XCTAssertEqual(view.string, "before after")
        XCTAssertEqual(view.selectedRange, collapsedSelection)
    }
}

private final class CutSelectionRecorder: NSObject, UITextInputDelegate {
    enum Phase {
        case willChange
        case didChange
    }

    struct Change: Equatable {
        let phase: Phase
        let text: String
        let selection: NSRange?
    }

    var changes: [Change] = []

    func selectionWillChange(_ textInput: UITextInput?) {
        record(.willChange, textInput: textInput)
    }

    func selectionDidChange(_ textInput: UITextInput?) {
        record(.didChange, textInput: textInput)
    }

    func textWillChange(_ textInput: UITextInput?) {}
    func textDidChange(_ textInput: UITextInput?) {}

    #if compiler(>=6.1)
    @available(iOS 18.4, *)
    func conversationContext(_ context: UIConversationContext?, didChange textInput: UITextInput?) {}
    #endif

    private func record(_ phase: Phase, textInput: UITextInput?) {
        guard let view = textInput as? TextInputView else {
            XCTFail("Selection notifications must identify the text input view")
            return
        }
        changes.append(Change(phase: phase, text: view.string as String, selection: view.selectedRange))
    }
}
