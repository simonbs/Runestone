import Combine
import Foundation

final class TextDeleter {
    private let stringView: CurrentValueSubject<StringView, Never>
    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let selectedRange: CurrentValueSubject<NSRange, Never>
    private let markedRange: CurrentValueSubject<NSRange?, Never>
    private let lineControllerStorage: LineControllerStorage
    private let textEditState: TextEditState
    private let textEditAllowedChecker: TextEditAllowedChecker
    private let textEditor: TextEditor
    private let undoManager: TextEditingUndoManager
    private let textInputDelegate: TextInputDelegate
    private let deletionRangeFactory: TextDeletionRangeFactory

    init(
        stringView: CurrentValueSubject<StringView, Never>,
        lineManager: CurrentValueSubject<LineManager, Never>,
        selectedRange: CurrentValueSubject<NSRange, Never>,
        markedRange: CurrentValueSubject<NSRange?, Never>,
        lineControllerStorage: LineControllerStorage,
        textEditState: TextEditState,
        textEditAllowedChecker: TextEditAllowedChecker,
        textEditor: TextEditor,
        undoManager: TextEditingUndoManager,
        textInputDelegate: TextInputDelegate,
        deletionRangeFactory: TextDeletionRangeFactory
    ) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.selectedRange = selectedRange
        self.markedRange = markedRange
        self.lineControllerStorage = lineControllerStorage
        self.textEditState = textEditState
        self.textEditAllowedChecker = textEditAllowedChecker
        self.textEditor = textEditor
        self.undoManager = undoManager
        self.textInputDelegate = textInputDelegate
        self.deletionRangeFactory = deletionRangeFactory
    }

    func deleteBackward() {
        let selectedRange = markedRange.value ?? selectedRange.value
        guard selectedRange.length > 0 else {
            return
        }
        let deleteRange = deletionRangeFactory.rangeForDeletingText(in: selectedRange)
        guard textEditAllowedChecker.shouldChangeText(in: deleteRange, replacementText: "") else {
            return
        }
        // If we're deleting everything in the marked range then we clear the marked range. UITextInput doesn't do that for us.
        // Can be tested by entering a backtick (`) in an empty document and deleting it.
        if deleteRange == markedRange.value {
            markedRange.value = nil
        }
        // Set a flag indicating that we have deleted text. This is reset in -layoutSubviews() but if this has not been reset before insertText() is called, then UIKit deleted characters prior to inserting combined characters. This happens when UIKit turns Korean characters into a single character. E.g. when typing ㅇ followed by ㅓ UIKit will perform the following operations:
        // 1. Delete ㅇ.
        // 2. Delete the character before ㅇ. I'm unsure why this is needed.
        // 3. Insert the character that was previously before ㅇ.
        // 4. Insert the ㅇ and ㅓ but combined into the single character delete ㅇ and then insert 어.
        // We can detect this case in insertText() by checking if this variable is true.
        textEditState.hasDeletedTextWithPendingLayoutSubviews = true
        // Disable notifying delegate in layout subviews to prevent sending the selected range with length > 0 when deleting text. This aligns with the behavior of UITextView and was introduced to resolve issue #158: https://github.com/simonbs/Runestone/issues/158
        textEditState.notifyDelegateAboutSelectionChangeInLayoutSubviews = false
        // Disable notifying input delegate in layout subviews to prevent issues when entering Korean text. This workaround is inspired by a dialog with Alexander Black (@lextar), developer of Textastic.
        textEditState.notifyInputDelegateAboutSelectionChangeInLayoutSubviews = false
        // Just before calling deleteBackward(), UIKit will set the selected range to a range of length 1, if the selected range has a length of 0.
        // In that case we want to undo to a selected range of length 0, so we construct our range here and pass it all the way to the undo operation.
        let selectedRangeAfterUndo = selectedRangeAfterUndo(forDeletingTextIn: deleteRange, forCurrentSelectedRange: selectedRange)
        let isDeletingMultipleCharacters = selectedRange.length > 1
        if isDeletingMultipleCharacters {
            undoManager.endUndoGrouping()
            undoManager.beginUndoGrouping()
        }
        undoManager.registerUndoOperation(
            named: L10n.Undo.ActionName.typing,
            forReplacingTextIn: deleteRange,
            selectedRangeAfterUndo: selectedRangeAfterUndo
        )
        textEditor.replaceText(in: deleteRange, with: "")
        // Sending selection changed without calling the input delegate directly. This ensures that both inputting Korean letters and deleting entire words with Option+Backspace works properly.
        textInputDelegate.selectionDidChange(sendAnonymously: true)
        if isDeletingMultipleCharacters {
            undoManager.endUndoGrouping()
        }
    }

    func deleteForward() {
        guard selectedRange.value.length == 0 else {
            deleteBackward()
            return
        }
        guard selectedRange.value.location < stringView.value.string.length else {
            return
        }
        selectedRange.value = NSRange(location: selectedRange.value.location, length: 1)
        deleteBackward()
    }

    func deleteWordForward() {
        deleteText(toBoundary: .word, inDirection: .forward)
    }

    func deleteWordBackward() {
        deleteText(toBoundary: .word, inDirection: .backward)
    }
}

private extension TextDeleter {
    private func selectedRangeAfterUndo(forDeletingTextIn deleteRange: NSRange, forCurrentSelectedRange selectedRange: NSRange) -> NSRange {
        if deleteRange.length == 1 {
            return NSRange(location: selectedRange.upperBound, length: 0)
        } else {
            return selectedRange
        }
    }

    private func deleteText(toBoundary boundary: TextBoundary, inDirection direction: TextDirection) {
        guard selectedRange.value.length == 0 else {
            deleteBackward()
            return
        }
        guard let range = rangeForDeleting(from: selectedRange.value.location, toBoundary: boundary, inDirection: direction) else {
            return
        }
        selectedRange.value = range
        deleteBackward()
    }

    private func rangeForDeleting(from sourceLocation: Int, toBoundary boundary: TextBoundary, inDirection direction: TextDirection) -> NSRange? {
        let stringTokenizer = StringTokenizer(
            stringView: stringView.value,
            lineManager: lineManager.value,
            lineControllerStorage: lineControllerStorage
        )
        guard let destinationLocation = stringTokenizer.location(from: sourceLocation, toBoundary: boundary, inDirection: direction) else {
            return nil
        }
        let lowerBound = min(sourceLocation, destinationLocation)
        let upperBound = max(sourceLocation, destinationLocation)
        return NSRange(location: lowerBound, length: upperBound - lowerBound)
    }
}
