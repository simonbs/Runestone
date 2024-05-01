#if os(iOS)
import UIKit

final class UITextInputClientTextEditingHandler {
    var hasText: Bool {
        stringView.length > 0
    }

    private let stringView: StringView
    private let textEditor: TextEditing

    init(stringView: StringView, textEditor: TextEditing) {
        self.stringView = stringView
        self.textEditor = textEditor
    }

    func text(in range: UITextRange) -> String? {
        guard let range = range as? RunestoneUITextRange else {
            return nil
        }
        return stringView.substring(in: range.range)
    }

    func replace(_ range: UITextRange, withText text: String) {
        guard let range = range as? RunestoneUITextRange else {
            return
        }
        textEditor.replaceText(in: range.range, with: text)
    }

    func insertText(_ text: String) {
        textEditor.insertText(text)
//        textEditState.isRestoringPreviouslyDeletedText = textEditState.hasDeletedTextWithPendingLayoutSubviews
//        textEditState.hasDeletedTextWithPendingLayoutSubviews = false
//        defer {
//            textEditState.isRestoringPreviouslyDeletedText = false
//        }
//        textEditor.insertText(text)
//        proxyView.view?.layoutIfNeeded()
    }

    func deleteBackward() {
        textEditor.deleteBackward()
    }

    func baseWritingDirection(
        for position: UITextPosition,
        in direction: UITextStorageDirection
    ) -> NSWritingDirection {
        .natural
    }

    func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {}
}
#endif
