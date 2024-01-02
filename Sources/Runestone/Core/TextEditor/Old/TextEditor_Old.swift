//import Foundation
//
//final class TextEditor: TextEditing {
//    let settings: Settings
//    let state: State
//    let stringView: StringViewType
//    let lineManager: LineManagerType
//    let stringTokenizer: StringTokenizerType
//    let languageMode: LanguageModeType
//    let textReplacer: TextReplacerType
//    let textViewDelegate: ErasedTextViewDelegate
//
//    private var hasDeletedTextWithPendingLayoutSubviews = false
//    private var notifyDelegateAboutSelectionChangeInLayoutSubviews = false
//    private var notifyInputDelegateAboutSelectionChangeInLayoutSubviews = false
//    private var isRestoringPreviouslyDeletedText = false
//
//    func insertText(_ text: String) {
//        isRestoringPreviouslyDeletedText = hasDeletedTextWithPendingLayoutSubviews
//        hasDeletedTextWithPendingLayoutSubviews = false
//        defer {
//            isRestoringPreviouslyDeletedText = false
//        }
//        if text == settings.lineEndings.symbol {
//            insertNewLine()
//        } else {
//            textReplacer.replaceText(in: insertRange, with: text)
//        }
//    }
//    
//    func insertNewLine() {
//        lineBreakInserter.insertLineBreak(in: insertRange)
//    }
//
//    func insertTab() {
//        let text = settings.indentStrategy.string(indentLevel: 1)
//        textReplacer.replaceText(in: insertRange, with: text)
//    }
//
//    func replaceText(in range: NSRange, with newText: String) {
//        let safeText = newText.replacingAllLineEndings(with: settings.lineEndings)
//        func performTextReplacementIfNeeded() {
//            if textViewDelegate.shouldChangeText(in: range, replacementText: safeText) {
//                //            undoManager.registerUndoOperation(named: L10n.Undo.ActionName.typing, forReplacingTextIn: range)
//                textReplacer.replaceText(in: range, with: safeText)
//                state.selectedRange = NSRange(location: range.location + safeText.utf16.count, length: 0)
//            }
//        }
//        guard !isRestoringPreviouslyDeletedText else {
//            // UIKit is inserting text to combine characters, for example to combine two Korean characters into one,
//            // and we do not want to interfere with that.
//            return performTextReplacementIfNeeded()
//        }
//        guard !characterPairInserter.handleInsertingCharacterPair(withComponent: newText, in: range) else {
//            return
//        }
//        performTextReplacementIfNeeded()
//    }
//
//    func deleteBackward() {
//        guard let deleteRange = deleteRangeFactory.deleteBackwardRange else {
//            return
//        }
//        guard textViewDelegate.shouldChangeText(in: deleteRange, replacementText: "") else {
//            return
//        }
//        // If we're deleting everything in the marked range then we clear the marked range. UITextInput doesn't do that for us.
//        // Can be tested by entering a backtick (`) in an empty document and deleting it.
//        if deleteRange == state.markedRange {
//            state.markedRange = nil
//        }
//        // Set a flag indicating that we have deleted text. This is reset in -layoutSubviews() but if this has not been reset before insertText() is called, then UIKit deleted characters prior to inserting combined characters. This happens when UIKit turns Korean characters into a single character. E.g. when typing ㅇ followed by ㅓ UIKit will perform the following operations:
//        // 1. Delete ㅇ.
//        // 2. Delete the character before ㅇ. I'm unsure why this is needed.
//        // 3. Insert the character that was previously before ㅇ.
//        // 4. Insert the ㅇ and ㅓ but combined into the single character delete ㅇ and then insert 어.
//        // We can detect this case in insertText() by checking if this variable is true.
////        textEditState.hasDeletedTextWithPendingLayoutSubviews = true
//        // Disable notifying delegate in layout subviews to prevent sending the selected range with length > 0 when deleting text. This aligns with the behavior of UITextView and was introduced to resolve issue #158: https://github.com/simonbs/Runestone/issues/158
////        textEditState.notifyDelegateAboutSelectionChangeInLayoutSubviews = false
//        // Disable notifying input delegate in layout subviews to prevent issues when entering Korean text. This workaround is inspired by a dialog with Alexander Black (@lextar), developer of Textastic.
////        textEditState.notifyInputDelegateAboutSelectionChangeInLayoutSubviews = false
////        let isDeletingMultipleCharacters = state.selectedRange.length > 1
////        if isDeletingMultipleCharacters {
////            undoManager.endUndoGrouping()
////            undoManager.beginUndoGrouping()
////        }
////        undoManager.registerUndoOperation(
////            named: L10n.Undo.ActionName.typing,
////            forReplacingTextIn: deleteRange
////        )
//        textReplacer.replaceText(in: deleteRange, with: "")
//        state.selectedRange = NSRange(location: deleteRange.location, length: 0)
//        // Sending selection changed without calling the input delegate directly. This ensures that both inputting Korean letters and deleting entire words with Option+Backspace works properly.
////        textInputDelegate.selectionDidChange(sendAnonymously: true)
////        if isDeletingMultipleCharacters {
////            undoManager.endUndoGrouping()
////        }
//    }
//
//    func deleteForward() {
//        guard state.selectedRange.length == 0 else {
//            deleteBackward()
//            return
//        }
//        guard let deleteRange = deleteRangeFactory.deleteForwardRange else {
//            return
//        }
//        state.selectedRange = deleteRange
//        deleteBackward()
//    }
//
//    func deleteWordForward() {
//        deleteText(toBoundary: .word, inDirection: .forward)
//    }
//
//    func deleteWordBackward() {
//        deleteText(toBoundary: .word, inDirection: .backward)
//    }
//}
//
//private extension TextEditor {
//    private func deleteText(toBoundary boundary: TextBoundary, inDirection direction: TextDirection) {
//        guard state.selectedRange.length == 0 else {
//            deleteBackward()
//            return
//        }
//        guard let range = deleteRangeFactory.rangeForDeleting(
//            from: state.selectedRange.location,
//            toBoundary: boundary,
//            inDirection: direction
//        ) else {
//            return
//        }
//        state.selectedRange = range
//        deleteBackward()
//    }
//}
