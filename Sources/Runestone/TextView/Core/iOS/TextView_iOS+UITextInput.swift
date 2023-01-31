#if os(iOS)
import UIKit

extension TextView: UITextInput {}

public extension TextView {
    var beginningOfDocument: UITextPosition {
        IndexedPosition(index: 0)
    }
    var endOfDocument: UITextPosition {
        IndexedPosition(index: textViewController.stringView.string.length)
    }
    var hasText: Bool {
        textViewController.stringView.string.length > 0
    }
    var tokenizer: UITextInputTokenizer {
        customTokenizer
    }
}

// MARK: - Caret
public extension TextView {
    func caretRect(for position: UITextPosition) -> CGRect {
        guard let indexedPosition = position as? IndexedPosition else {
            fatalError("Expected position to be of type \(IndexedPosition.self)")
        }
        return textViewController.caretRectService.caretRect(
            at: indexedPosition.index,
            allowMovingCaretToNextLineFragment: true
        )
    }

    func beginFloatingCursor(at point: CGPoint) {
        guard floatingCaretView == nil, let position = closestPosition(to: point) else {
            return
        }
        insertionPointColorBeforeFloatingBegan = insertionPointColor
        insertionPointColor = insertionPointColorBeforeFloatingBegan.withAlphaComponent(0.5)
        updateCaretColor()
        let caretRect = self.caretRect(for: position)
        let caretOrigin = CGPoint(x: point.x - caretRect.width / 2, y: point.y - caretRect.height / 2)
        let floatingCaretView = FloatingCaretView()
        floatingCaretView.backgroundColor = insertionPointColorBeforeFloatingBegan
        floatingCaretView.frame = CGRect(origin: caretOrigin, size: caretRect.size)
        addSubview(floatingCaretView)
        self.floatingCaretView = floatingCaretView
        editorDelegate?.textViewDidBeginFloatingCursor(self)
    }

    func updateFloatingCursor(at point: CGPoint) {
        if let floatingCaretView = floatingCaretView {
            let caretSize = floatingCaretView.frame.size
            let caretOrigin = CGPoint(x: point.x - caretSize.width / 2, y: point.y - caretSize.height / 2)
            floatingCaretView.frame = CGRect(origin: caretOrigin, size: caretSize)
        }
    }

    func endFloatingCursor() {
        insertionPointColor = insertionPointColorBeforeFloatingBegan
        updateCaretColor()
        floatingCaretView?.removeFromSuperview()
        floatingCaretView = nil
        editorDelegate?.textViewDidEndFloatingCursor(self)
    }

    func updateCaretColor() {
        // Removing the UITextSelectionView and re-adding it forces it to query the insertion point color.
        if let textSelectionView = textSelectionView {
            textSelectionView.removeFromSuperview()
            addSubview(textSelectionView)
        }
    }
}

// MARK: - Editing
public extension TextView {
    func text(in range: UITextRange) -> String? {
        if let indexedRange = range as? IndexedRange {
            return textViewController.text(in: indexedRange.range)
        } else {
            return nil
        }
    }

    func replace(_ range: UITextRange, withText text: String) {
        let preparedText = textViewController.prepareTextForInsertion(text)
        guard let indexedRange = range as? IndexedRange else {
            return
        }
        guard textViewController.shouldChangeText(in: indexedRange.range.nonNegativeLength, replacementText: preparedText) else {
            return
        }
        textViewController.replaceText(in: indexedRange.range.nonNegativeLength, with: preparedText)
        handleTextSelectionChange()
    }

    func insertText(_ text: String) {
        isRestoringPreviouslyDeletedText = hasDeletedTextWithPendingLayoutSubviews
        hasDeletedTextWithPendingLayoutSubviews = false
        defer {
            isRestoringPreviouslyDeletedText = false
        }
        let preparedText = textViewController.prepareTextForInsertion(text)
        guard textViewController.shouldChangeText(in: selectedRange, replacementText: preparedText) else {
            return
        }
        // If we're inserting text then we can't have a marked range. However, UITextInput doesn't always clear the marked range
        // before calling -insertText(_:), so we do it manually. This issue can be tested by entering a backtick (`) in an empty
        // document, then pressing any arrow key (up, right, down or left) followed by the return key.
        // The backtick will remain marked unless we manually clear the marked range.
        textViewController.markedRange = nil
        if LineEnding(symbol: text) != nil {
            textViewController.indentController.insertLineBreak(in: selectedRange, using: lineEndings)
        } else {
            textViewController.replaceText(in: selectedRange, with: preparedText)
        }
        layoutIfNeeded()
        handleTextSelectionChange()
    }

    func deleteBackward() {
        guard let selectedRange = textViewController.markedRange ?? textViewController.selectedRange, selectedRange.length > 0 else {
            return
        }
        let deleteRange = textViewController.rangeForDeletingText(in: selectedRange)
        // If we're deleting everything in the marked range then we clear the marked range. UITextInput doesn't do that for us.
        // Can be tested by entering a backtick (`) in an empty document and deleting it.
        if deleteRange == textViewController.markedRange {
            textViewController.markedRange = nil
        }
        guard textViewController.shouldChangeText(in: deleteRange, replacementText: "") else {
            return
        }
        // Set a flag indicating that we have deleted text. This is reset in -layoutSubviews() but if this has not been reset before insertText() is called, then UIKit deleted characters prior to inserting combined characters. This happens when UIKit turns Korean characters into a single character. E.g. when typing ㅇ followed by ㅓ UIKit will perform the following operations:
        // 1. Delete ㅇ.
        // 2. Delete the character before ㅇ. I'm unsure why this is needed.
        // 3. Insert the character that was previously before ㅇ.
        // 4. Insert the ㅇ and ㅓ but combined into the single character delete ㅇ and then insert 어.
        // We can detect this case in insertText() by checking if this variable is true.
        hasDeletedTextWithPendingLayoutSubviews = true
        // Disable notifying delegate in layout subviews to prevent sending the selected range with length > 0 when deleting text. This aligns with the behavior of UITextView and was introduced to resolve issue #158: https://github.com/simonbs/Runestone/issues/158
        notifyDelegateAboutSelectionChangeInLayoutSubviews = false
        // Disable notifying input delegate in layout subviews to prevent issues when entering Korean text. This workaround is inspired by a dialog with Alexander Black (@lextar), developer of Textastic.
        notifyInputDelegateAboutSelectionChangeInLayoutSubviews = false
        // Just before calling deleteBackward(), UIKit will set the selected range to a range of length 1, if the selected range has a length of 0.
        // In that case we want to undo to a selected range of length 0, so we construct our range here and pass it all the way to the undo operation.
        let selectedRangeAfterUndo: NSRange
        if deleteRange.length == 1 {
            selectedRangeAfterUndo = NSRange(location: selectedRange.upperBound, length: 0)
        } else {
            selectedRangeAfterUndo = selectedRange
        }
        let isDeletingMultipleCharacters = selectedRange.length > 1
        if isDeletingMultipleCharacters {
            undoManager?.endUndoGrouping()
            undoManager?.beginUndoGrouping()
        }
        textViewController.replaceText(in: deleteRange, with: "", selectedRangeAfterUndo: selectedRangeAfterUndo)
        // Sending selection changed without calling the input delegate directly. This ensures that both inputting Korean letters and deleting entire words with Option+Backspace works properly.
        sendSelectionChangedToTextSelectionView()
        if isDeletingMultipleCharacters {
            undoManager?.endUndoGrouping()
        }
        handleTextSelectionChange()
    }
}

// MARK: - Selection
public extension TextView {
    var selectedTextRange: UITextRange? {
        get {
            if let range = textViewController.selectedRange {
                return IndexedRange(range)
            } else {
                return nil
            }
        }
        set {
            // We should not use this setter. It's intended for UIKit to use. It'll invoke the setter in various scenarios, for example when navigating the text using the keyboard.
            // On the iOS 16 beta, UIKit may pass an NSRange with a negatives length (e.g. {4, -2}) when double tapping to select text. This will cause a crash when UIKit later attempts to use the selected range with NSString's -substringWithRange:. This can be tested with a string containing the following three lines:
            //    A
            //
            //    A
            // Placing the character on the second line, which is empty, and double tapping several times on the empty line to select text will cause the editor to crash. To work around this we take the non-negative value of the selected range. Last tested on August 30th, 2022.
            let newRange = (newValue as? IndexedRange)?.range.nonNegativeLength
            if newRange != textViewController.selectedRange {
                notifyDelegateAboutSelectionChangeInLayoutSubviews = true
                // The logic for determining whether or not to notify the input delegate is based on advice provided by Alexander Blach, developer of Textastic.
                var shouldNotifyInputDelegate = false
                if didCallPositionFromPositionInDirectionWithOffset {
                    shouldNotifyInputDelegate = true
                    didCallPositionFromPositionInDirectionWithOffset = false
                }
                notifyInputDelegateAboutSelectionChangeInLayoutSubviews = !shouldNotifyInputDelegate
                if shouldNotifyInputDelegate {
                    inputDelegate?.selectionWillChange(self)
                }
                textViewController.selectedRange = newRange
                if shouldNotifyInputDelegate {
                    inputDelegate?.selectionDidChange(self)
                }
            }
        }
    }

    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        if let indexedRange = range as? IndexedRange {
            return textViewController.selectionRectService.selectionRects(in: indexedRange.range.nonNegativeLength)
        } else {
            return []
        }
    }
}

// MARK: - Marking
public extension TextView {
    var markedTextStyle: [NSAttributedString.Key : Any]? {
        get { return nil }
        set {}
    }

    var markedTextRange: UITextRange? {
        get {
            if let markedRange = textViewController.markedRange {
                return IndexedRange(markedRange)
            } else {
                return nil
            }
        }
        set {
            textViewController.markedRange = (newValue as? IndexedRange)?.range.nonNegativeLength
        }
    }

    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        guard let range = textViewController.markedRange ?? textViewController.selectedRange else {
            return
        }
        let markedText = markedText ?? ""
        guard textViewController.shouldChangeText(in: range, replacementText: markedText) else {
            return
        }
        textViewController.markedRange = markedText.isEmpty ? nil : NSRange(location: range.location, length: markedText.utf16.count)
        textViewController.replaceText(in: range, with: markedText)
        // The selected range passed to setMarkedText(_:selectedRange:) is local to the marked range.
        let preferredSelectedRange = NSRange(location: range.location + selectedRange.location, length: selectedRange.length)
        inputDelegate?.selectionWillChange(self)
        textViewController.selectedRange = textViewController.safeSelectionRange(from: preferredSelectedRange)
        inputDelegate?.selectionDidChange(self)
        removeAndAddEditableTextInteraction()
    }

    func unmarkText() {
        inputDelegate?.selectionWillChange(self)
        textViewController.markedRange = nil
        inputDelegate?.selectionDidChange(self)
        removeAndAddEditableTextInteraction()
    }
}

// MARK: - Ranges and Positions
public extension TextView {
    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        guard let fromIndexedPosition = fromPosition as? IndexedPosition, let toIndexedPosition = toPosition as? IndexedPosition else {
            return nil
        }
        let range = NSRange(location: fromIndexedPosition.index, length: toIndexedPosition.index - fromIndexedPosition.index)
        return IndexedRange(range)
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        guard let indexedPosition = position as? IndexedPosition else {
            return nil
        }
        let newPosition = indexedPosition.index + offset
        guard newPosition >= 0 && newPosition <= textViewController.stringView.string.length else {
            return nil
        }
        return IndexedPosition(index: newPosition)
    }

    func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        guard let indexedPosition = position as? IndexedPosition else {
            return nil
        }
        didCallPositionFromPositionInDirectionWithOffset = true
        let navigationService = textViewController.navigationService
        switch direction {
        case .right:
            let newLocation = navigationService.location(movingFrom: indexedPosition.index, by: .character, offset: offset)
            return IndexedPosition(index: newLocation)
        case .left:
            let newLocation = navigationService.location(movingFrom: indexedPosition.index, by: .character, offset: offset * -1)
            return IndexedPosition(index: newLocation)
        case .up:
            let newLocation = navigationService.location(movingFrom: indexedPosition.index, by: .line, offset: offset * -1)
            return IndexedPosition(index: newLocation)
        case .down:
            let newLocation = navigationService.location(movingFrom: indexedPosition.index, by: .line, offset: offset)
            return IndexedPosition(index: newLocation)
        @unknown default:
            return nil
        }
    }

    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        guard let indexedPosition = position as? IndexedPosition, let otherIndexedPosition = other as? IndexedPosition else {
            #if targetEnvironment(macCatalyst)
            // Mac Catalyst may pass <uninitialized> to `position`. I'm not sure what the right way to deal with that is but returning .orderedSame seems to work.
            return .orderedSame
            #else
            fatalError("Positions must be of type \(IndexedPosition.self)")
            #endif
        }
        if indexedPosition.index < otherIndexedPosition.index {
            return .orderedAscending
        } else if indexedPosition.index > otherIndexedPosition.index {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }

    func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int {
        if let fromPosition = from as? IndexedPosition, let toPosition = toPosition as? IndexedPosition {
            return toPosition.index - fromPosition.index
        } else {
            return 0
        }
    }

    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        // This implementation seems to match the behavior of UITextView.
        guard let indexedRange = range as? IndexedRange else {
            return nil
        }
        switch direction {
        case .left, .up:
            return IndexedPosition(index: indexedRange.range.lowerBound)
        case .right, .down:
            return IndexedPosition(index: indexedRange.range.upperBound)
        @unknown default:
            return nil
        }
    }

    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        // This implementation seems to match the behavior of UITextView.
        guard let indexedPosition = position as? IndexedPosition else {
            return nil
        }
        switch direction {
        case .left, .up:
            let leftIndex = max(indexedPosition.index - 1, 0)
            return IndexedRange(location: leftIndex, length: indexedPosition.index - leftIndex)
        case .right, .down:
            let rightIndex = min(indexedPosition.index + 1, textViewController.stringView.string.length)
            return IndexedRange(location: indexedPosition.index, length: rightIndex - indexedPosition.index)
        @unknown default:
            return nil
        }
    }

    func firstRect(for range: UITextRange) -> CGRect {
        guard let indexedRange = range as? IndexedRange else {
            fatalError("Expected range to be of type \(IndexedRange.self)")
        }
        return textViewController.layoutManager.firstRect(for: indexedRange.range)
    }

    func closestPosition(to point: CGPoint) -> UITextPosition? {
        if let index = textViewController.layoutManager.closestIndex(to: point) {
            return IndexedPosition(index: index)
        } else {
            return nil
        }
    }

    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        guard let indexedRange = range as? IndexedRange else {
            return nil
        }
        guard let index = textViewController.layoutManager.closestIndex(to: point) else {
            return nil
        }
        let minimumIndex = indexedRange.range.lowerBound
        let maximumIndex = indexedRange.range.upperBound
        let cappedIndex = min(max(index, minimumIndex), maximumIndex)
        return IndexedPosition(index: cappedIndex)
    }

    func characterRange(at point: CGPoint) -> UITextRange? {
        guard let index = textViewController.layoutManager.closestIndex(to: point) else {
            return nil
        }
        let cappedIndex = max(index - 1, 0)
        let range = textViewController.stringView.string.customRangeOfComposedCharacterSequence(at: cappedIndex)
        return IndexedRange(range)
    }
}

// MARK: - Writing Direction
public extension TextView {
    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection {
        .natural
    }

    func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {}
}
#endif
