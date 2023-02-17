// swiftlint:disable file_length
#if os(iOS)
import UIKit

extension TextView: UITextInput {}

public extension TextView {
    /// The text position for the beginning of a document.
    var beginningOfDocument: UITextPosition {
        IndexedPosition(index: 0)
    }
    /// The text position for the end of a document.
    var endOfDocument: UITextPosition {
        IndexedPosition(index: textViewController.stringView.string.length)
    }
    /// Returns a Boolean value indicating whether the text view currently contains any text.
    var hasText: Bool {
        textViewController.stringView.string.length > 0
    }
    /// An input tokenizer that provides information about the granularity of text units.
    var tokenizer: UITextInputTokenizer {
        customTokenizer
    }
}

// MARK: - Caret
public extension TextView {
    /// Returns a rectangle to draw the caret at a specified insertion point.
    /// - Parameter position: An object that identifies a location in a text input area.
    /// - Returns: A rectangle that defines the area for drawing the caret.
    func caretRect(for position: UITextPosition) -> CGRect {
        guard let indexedPosition = position as? IndexedPosition else {
            fatalError("Expected position to be of type \(IndexedPosition.self)")
        }
        let caretFactory = CaretRectFactory(
            stringView: textViewController.stringView,
            lineManager: textViewController.lineManager,
            lineControllerStorage: textViewController.lineControllerStorage,
            gutterWidthService: textViewController.gutterWidthService,
            textContainerInset: textContainerInset
        )
        return caretFactory.caretRect(at: indexedPosition.index, allowMovingCaretToNextLineFragment: true)
    }

    /// Called at the beginning of the gesture that the system uses to manipulate the cursor.
    /// - Parameter point: The point at which the gesture occurred in your view.
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

    /// Called to move the floating cursor to a new location.
    /// - Parameter point: The new touch point in the underlying view.
    func updateFloatingCursor(at point: CGPoint) {
        if let floatingCaretView = floatingCaretView {
            let caretSize = floatingCaretView.frame.size
            let caretOrigin = CGPoint(x: point.x - caretSize.width / 2, y: point.y - caretSize.height / 2)
            floatingCaretView.frame = CGRect(origin: caretOrigin, size: caretSize)
        }
    }

    /// Called at the end of the gesture that the system uses to manipulate the cursor.
    func endFloatingCursor() {
        insertionPointColor = insertionPointColorBeforeFloatingBegan
        updateCaretColor()
        floatingCaretView?.removeFromSuperview()
        floatingCaretView = nil
        editorDelegate?.textViewDidEndFloatingCursor(self)
    }
}

// MARK: - Editing
public extension TextView {
    /// Returns the text in the specified range.
    /// - Parameter range: A range of text in a document.
    /// - Returns: A substring of a document that falls within the specified range.
    func text(in range: UITextRange) -> String? {
        if let indexedRange = range as? IndexedRange {
            return textViewController.text(in: indexedRange.range)
        } else {
            return nil
        }
    }

    /// Replaces the text in a document that is in the specified range.
    /// - Parameters:
    ///   - range: A range of text in a document.
    ///   - text: A string to replace the text in range.
    func replace(_ range: UITextRange, withText text: String) {
        let preparedText = textViewController.prepareTextForInsertion(text)
        guard let indexedRange = range as? IndexedRange else {
            return
        }
        guard textViewController.shouldChangeText(in: indexedRange.range.nonNegativeLength, replacementText: preparedText) else {
            return
        }
        textViewController.replaceText(in: indexedRange.range.nonNegativeLength, with: preparedText)
    }

    /// Inserts a character into the displayed text.
    /// - Parameter text: A string object representing the character typed on the system keyboard.
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
            textViewController.indentController.insertLineBreak(in: selectedRange, using: lineEndings.symbol)
        } else {
            textViewController.replaceText(in: selectedRange, with: preparedText)
        }
        layoutIfNeeded()
    }

    /// Deletes a character from the displayed text.
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
    }
}

// MARK: - Selection
public extension TextView {
    /// The range of selected text in a document.
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
                textViewController._selectedRange = newRange
                if shouldNotifyInputDelegate {
                    inputDelegate?.selectionDidChange(self)
                }
            }
        }
    }

    /// Returns an array of selection rects corresponding to the range of text.
    /// - Parameter range: An object representing a range in a document's text.
    /// - Returns: An array of UITextSelectionRect objects that encompass the selection.
    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        guard let indexedRange = range as? IndexedRange else {
            return []
        }
        let caretRectFactory = CaretRectFactory(
            stringView: textViewController.stringView,
            lineManager: textViewController.lineManager,
            lineControllerStorage: textViewController.lineControllerStorage,
            gutterWidthService: textViewController.gutterWidthService,
            textContainerInset: textContainerInset
        )
        let selectionRectFactory = SelectionRectFactory(
            lineManager: textViewController.lineManager,
            gutterWidthService: textViewController.gutterWidthService,
            contentSizeService: textViewController.contentSizeService,
            caretRectFactory: caretRectFactory,
            textContainerInset: textContainerInset,
            lineHeightMultiplier: lineHeightMultiplier
        )
        return selectionRectFactory.selectionRects(in: indexedRange.range)
    }
}

// MARK: - Marking
public extension TextView {
    // swiftlint:disable unused_setter_value
    /// A dictionary of attributes that describes how to draw marked text.
    var markedTextStyle: [NSAttributedString.Key: Any]? {
        get { nil }
        set {}
    }
    // swiftlint:enable unused_setter_value

    /// The range of currently marked text in a document.
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

    /// Inserts the provided text and marks it to indicate that it is part of an active input session.
    /// - Parameters:
    ///   - markedText: The text to be marked.
    ///   - selectedRange: A range within `markedText` that indicates the current selection. This range is always relative to `markedText`.
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
        textViewController._selectedRange = preferredSelectedRange.capped(to: textViewController.stringView.string.length)
        inputDelegate?.selectionDidChange(self)
        removeAndAddEditableTextInteraction()
    }

    /// Unmarks the currently marked text.
    func unmarkText() {
        inputDelegate?.selectionWillChange(self)
        textViewController.markedRange = nil
        inputDelegate?.selectionDidChange(self)
        removeAndAddEditableTextInteraction()
    }
}

// MARK: - Ranges and Positions
public extension TextView {
    /// Returns the range between two text positions.
    /// - Parameters:
    ///   - fromPosition: An object that represents a location in a document.
    ///   - toPosition: An object that represents another location in a document.
    /// - Returns: An object that represents the range between `fromPosition` and `toPosition`.
    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        guard let fromIndexedPosition = fromPosition as? IndexedPosition, let toIndexedPosition = toPosition as? IndexedPosition else {
            return nil
        }
        let range = NSRange(location: fromIndexedPosition.index, length: toIndexedPosition.index - fromIndexedPosition.index)
        return IndexedRange(range)
    }

    /// Returns the text position at a specified offset from another text position.
    /// - Parameters:
    ///   - position: A custom UITextPosition object that represents a location in a document.
    ///   - offset: A character offset from position. It can be a positive or negative value.
    /// - Returns: A custom UITextPosition object that represents the location in a document that is at the specified offset from position.
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

    /// Returns the text position at a specified offset in a specified direction from another text position.
    /// - Parameters:
    ///   - position: A custom UITextPosition object that represents a location in a document.
    ///   - direction: A UITextLayoutDirection constant that represents the direction of the offset from `position`.
    ///   - offset: A character offset from position.
    /// - Returns: Returns the text position at a specified offset in a specified direction from another text position.
    func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        guard let indexedPosition = position as? IndexedPosition else {
            return nil
        }
        didCallPositionFromPositionInDirectionWithOffset = true
        let navigationService = textViewController.navigationService
        switch direction {
        case .right:
            let newLocation = navigationService.location(movingFrom: indexedPosition.index, byCharacterCount: offset, inDirection: .forward)
            return IndexedPosition(index: newLocation)
        case .left:
            let newLocation = navigationService.location(movingFrom: indexedPosition.index, byCharacterCount: offset, inDirection: .backward)
            return IndexedPosition(index: newLocation)
        case .up:
            let newLocation = navigationService.location(movingFrom: indexedPosition.index, byLineCount: offset, inDirection: .backward)
            return IndexedPosition(index: newLocation)
        case .down:
            let newLocation = navigationService.location(movingFrom: indexedPosition.index, byLineCount: offset, inDirection: .forward)
            return IndexedPosition(index: newLocation)
        @unknown default:
            return nil
        }
    }

    /// Returns how one text position compares to another text position.
    /// - Parameters:
    ///   - position: A custom object that represents a location within a document.
    ///   - other: A custom object that represents another location within a document.
    /// - Returns: A value that indicates whether the two text positions are identical or whether one is before the other.
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

    /// Returns the number of UTF-16 characters between one text position and another text position.
    /// - Parameters:
    ///   - from: A custom object that represents a location within a document.
    ///   - toPosition: A custom object that represents another location within document.
    /// - Returns: The number of UTF-16 characters between `fromPosition` and `toPosition`.
    func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int {
        if let fromPosition = from as? IndexedPosition, let toPosition = toPosition as? IndexedPosition {
            return toPosition.index - fromPosition.index
        } else {
            return 0
        }
    }

    /// Returns the text position that is at the farthest extent in a specified layout direction within a range of text.
    /// - Parameters:
    ///   - range: A text-range object that demarcates a range of text in a document.
    ///   - direction: A constant that indicates a direction of layout (right, left, up, down).
    /// - Returns: A text-position object that identifies a location in the visible text.
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

    /// Returns a text range from a specified text position to its farthest extent in a certain direction of layout.
    /// - Parameters:
    ///   - position: A text-position object that identifies a location in a document.
    ///   - direction: A constant that indicates a direction of layout (right, left, up, down).
    /// - Returns: A text-range object that represents the distance from `position` to the farthest extent in `direction`.
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

    /// Returns the first rectangle that encloses a range of text in a document.
    /// - Parameter range: An object that represents a range of text in a document.
    /// - Returns: The first rectangle in a range of text. You might use this rectangle to draw a correction rectangle. The “first” in the name refers the rectangle enclosing the first line when the range encompasses multiple lines of text.
    func firstRect(for range: UITextRange) -> CGRect {
        guard let indexedRange = range as? IndexedRange else {
            fatalError("Expected range to be of type \(IndexedRange.self)")
        }
        return textViewController.layoutManager.firstRect(for: indexedRange.range)
    }

    /// Returns the position in a document that is closest to a specified point.
    /// - Parameter point: A point in the view that is drawing a document's text.
    /// - Returns: An object locating a position in a document that is closest to `point`.
    func closestPosition(to point: CGPoint) -> UITextPosition? {
        let index = textViewController.layoutManager.closestIndex(to: point)
        return IndexedPosition(index: index)
    }

    /// Returns the position in a document that is closest to a specified point in a specified range.
    /// - Parameters:
    ///   - point: A point in the view that is drawing a document's text.
    ///   - range: An object representing a range in a document's text.
    /// - Returns: An object representing the character position in range that is closest to `point`.
    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        guard let indexedRange = range as? IndexedRange else {
            return nil
        }
        let index = textViewController.layoutManager.closestIndex(to: point)
        let minimumIndex = indexedRange.range.lowerBound
        let maximumIndex = indexedRange.range.upperBound
        let cappedIndex = min(max(index, minimumIndex), maximumIndex)
        return IndexedPosition(index: cappedIndex)
    }

    /// Returns the character or range of characters that is at a specified point in a document.
    /// - Parameter point: A point in the view that is drawing a document's text.
    /// - Returns: An object representing a range that encloses a character (or characters) at `point`.
    func characterRange(at point: CGPoint) -> UITextRange? {
        let index = textViewController.layoutManager.closestIndex(to: point)
        let cappedIndex = max(index - 1, 0)
        let range = textViewController.stringView.string.customRangeOfComposedCharacterSequence(at: cappedIndex)
        return IndexedRange(range)
    }
}

// MARK: - Writing Direction
public extension TextView {
    /// Returns the base writing direction for a position in the text going in a certain direction.
    /// - Parameters:
    ///   - position: An object that identifies a location in a document.
    ///   - direction: A constant that indicates a direction of storage (forward or backward).
    /// - Returns: A constant that represents a writing direction (for example, left-to-right or right-to-left).
    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection {
        .natural
    }

    /// Sets the base writing direction for a specified range of text in a document.
    /// - Parameters:
    ///   - writingDirection: A constant that represents a writing direction (for example, left-to-right or right-to-left)
    ///   - range: An object that represents a range of text in a document.
    func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {}
}
#endif
