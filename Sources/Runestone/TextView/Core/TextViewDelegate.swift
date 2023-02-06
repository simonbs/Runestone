import Foundation

/// The methods for receiving editing-related messages for the text view.
public protocol TextViewDelegate: AnyObject {
    /// Asks the delegate whether to begin editing in the text view.
    /// - Parameter textView: The text view for which editing is about to begin.
    /// - Returns: `true` if editing should be initiated; otherwise, `false` to disallow editing.
    ///
    /// When the user performs an action that will begin editing, the text view calls this method to see if editing should actually proceed.
    ///
    /// Implementation of this method by is optional and if no implementaion is present, editing will be begin as if the method had returned `true`.
    func textViewShouldBeginEditing(_ textView: TextView) -> Bool
    /// Asks the delegate whether to stop editing in the text view.
    /// - Parameter textView: The text view for which editing is about to end.
    /// - Returns: `true` if editing should stop; otherwise, `false` if editing should continue.
    ///
    /// This method is called when the text view is asked to resign the first responder status.
    ///
    /// Implementation of this method by is optional and if no implementaion is present, editing will be end as if the method had returned `true`.
    func textViewShouldEndEditing(_ textView: TextView) -> Bool
    /// Tells the delegate when editing of the text view begins.
    /// - Parameter textView: The text view in which editing began.
    func textViewDidBeginEditing(_ textView: TextView)
    /// Tells the delegate when editing of the text view ends.
    /// - Parameter textView: The text view in which editing ended.
    func textViewDidEndEditing(_ textView: TextView)
    /// Tells the delegate when the user changes the text in the text view.
    /// - Parameter textView: The text view containing the changes.
    func textViewDidChange(_ textView: TextView)
    /// Tells the delegate when the text selection changes in the text view.
    /// - Parameter textView: The text view whose selection changed.
    ///
    /// You can use ``TextView/selectedRange`` of the text view to get the new selection.
    func textViewDidChangeSelection(_ textView: TextView)
    /// Asks the delegate whether to replace the specified text in the text view.
    /// - Parameters:
    ///   - textView: The text view containing the changes.
    ///   - range: The current selection range. If the length of the range is 0, range reflects the current insertion point. If the user presses the Delete key, the length of the range is 1 and an empty string object replaces that single character.
    ///   - text: The text to insert.
    /// - Returns: `true` if the old text should be replaced by the new text; `false` if the replacement operation should be aborted.
    ///
    /// The text view calls this method whenever the user types a new character or deletes an existing character.
    func textView(_ textView: TextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
    /// Asks the delegate whether to insert a character pair in the specified range.
    /// - Parameters:
    ///   - textView: The text view in which to insert the character pair.
    ///   - characterPair: The character pair to insert.
    ///   - range: The range in the text view in which the character pair should be inserted.
    /// - Returns: `true` if the character pair should be inserted; `false` if the operation should be aborted.
    ///
    /// Inserting the character pair will replace any existing text in the specified range.
    func textView(_ textView: TextView, shouldInsert characterPair: CharacterPair, in range: NSRange) -> Bool
    /// Asks the delegate if it should skip the trailing component of a character pair.
    /// - Parameters:
    ///   - textView: The text view in which the traling character pair is being inserted.
    ///   - characterPair: The character pair being inserted.
    ///   - range: The range in the text view in which the character pair should be inserted.
    /// - Returns: `true` if the trailing component should be skipped; `false` to insert the trailing component.
    ///
    /// When typing the trailing component of a character pair, e.g. ) or } and the cursor is just in front of that character, the delegate is asked whether the text view should skip inserting that character. If the character is skipped, then the caret is moved after the trailing character component.
    ///
    /// Implementation of this method by is optional and if no implementaion is present, the trailing component will be skipped as if the method had returned `true`.
    func textView(_ textView: TextView, shouldSkipTrailingComponentOf characterPair: CharacterPair, in range: NSRange) -> Bool
    /// Tells the delegate that the width of the gutter changed.
    /// - Parameter textView: The text view in which the gutter widht changed.
    ///
    /// The gutter width may change when inserting or deleting lines, possibly causing the widest text in the gutter to change.
    func textViewDidChangeGutterWidth(_ textView: TextView)
    /// Tells the delegate that a floating cursor interaction was started.
    /// - Parameter textView: The text view in which the interaction started.
    ///
    /// The floating cursor interaction may start in response to the user long pressing the cursor to move it around.
    func textViewDidBeginFloatingCursor(_ textView: TextView)
    /// Tells the delegate that a floating cursor interaction was ended.
    /// - Parameter textView: The text view in which the interaction ended.
    ///
    /// The floating cursor interaction ends when the user lets go of the cursor after long pressing it to move it around.
    func textViewDidEndFloatingCursor(_ textView: TextView)
    /// Tells the delegate that the text view looped to the last highlighted range.
    /// - Parameter textView: The text view that looped to the last highlighted range.
    ///
    /// The text view will loop to the last highlighted range in response to calling ``TextView/selectPreviousHighlightedRange()`` while the first highlighted range is selected.
    func textViewDidLoopToLastHighlightedRange(_ textView: TextView)
    /// Tells the delegate that the text view looped to the first highlighted range.
    /// - Parameter textView: The text view that looped to the first highlighted range.
    ///
    /// The text view will loop to the first highlighted range in response to calling ``TextView/selectNextHighlightedRange()`` while the last highlighted range is selected.
    func textViewDidLoopToFirstHighlightedRange(_ textView: TextView)
    /// Asks the delegate if the text in the highlighted range can be replaced.
    /// - Parameters:
    ///   - textView: The text view which is about to show a replace action.
    ///   - highlightedRange: The highlighted range for which the replace action will be shown.
    /// - Returns: `true` if the highlighted range can be replaced; otherwise `false`.
    ///
    /// The text view will call this method before showing a replace action, for example in a [UIMenuController](https://developer.apple.com/documentation/uikit/uimenucontroller).
    func textView(_ textView: TextView, canReplaceTextIn highlightedRange: HighlightedRange) -> Bool
    /// Tells the delegate to replace the text in the specified highlighted range.
    /// - Parameters:
    ///   - textView: The text view in which to replace the text.
    ///   - highlightedRange: The highlighted range in which to replace the text.
    ///
    /// The text view will call this method when the user chooses to replace the text in the highlighted range, for example by selecting the action in a [UIMenuController](https://developer.apple.com/documentation/uikit/uimenucontroller).
    func textView(_ textView: TextView, replaceTextIn highlightedRange: HighlightedRange)
}

public extension TextViewDelegate {
    func textViewShouldBeginEditing(_ textView: TextView) -> Bool {
        true
    }

    func textViewShouldEndEditing(_ textView: TextView) -> Bool {
        true
    }

    func textViewDidBeginEditing(_ textView: TextView) {}

    func textViewDidEndEditing(_ textView: TextView) {}

    func textViewDidChange(_ textView: TextView) {}

    func textViewDidChangeSelection(_ textView: TextView) {}

    func textView(_ textView: TextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        true
    }

    func textView(_ textView: TextView, shouldInsert characterPair: CharacterPair, in range: NSRange) -> Bool {
        true
    }

    func textView(_ textView: TextView, shouldSkipTrailingComponentOf characterPair: CharacterPair, in range: NSRange) -> Bool {
        true
    }

    func textViewDidChangeGutterWidth(_ textView: TextView) {}

    func textViewDidBeginFloatingCursor(_ textView: TextView) {}

    func textViewDidEndFloatingCursor(_ textView: TextView) {}

    func textViewDidLoopToLastHighlightedRange(_ textView: TextView) {}

    func textViewDidLoopToFirstHighlightedRange(_ textView: TextView) {}

    func textView(_ textView: TextView, canReplaceTextIn highlightedRange: HighlightedRange) -> Bool {
        false
    }

    func textView(_ textView: TextView, replaceTextIn highlightedRange: HighlightedRange) {}
}
