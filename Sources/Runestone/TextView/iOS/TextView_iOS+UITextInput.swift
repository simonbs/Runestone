// swiftlint:disable file_length
#if os(iOS)
import UIKit

extension TextView: UITextInput {}

public extension TextView {
    /// The text position for the beginning of a document.
    var beginningOfDocument: UITextPosition {
        textContainerView.beginningOfDocument
    }
    /// The text position for the end of a document.
    var endOfDocument: UITextPosition {
        textContainerView.endOfDocument
    }
    /// Returns a Boolean value indicating whether the text view currently contains any text.
    var hasText: Bool {
        textContainerView.hasText
    }
    /// An input tokenizer that provides information about the granularity of text units.
    var tokenizer: UITextInputTokenizer {
        textContainerView.tokenizer
    }
}

// MARK: - Caret
public extension TextView {
    /// Returns a rectangle to draw the caret at a specified insertion point.
    /// - Parameter position: An object that identifies a location in a text input area.
    /// - Returns: A rectangle that defines the area for drawing the caret.
    func caretRect(for position: UITextPosition) -> CGRect {
        textContainerView.caretRect(for: position)
    }

    /// Called at the beginning of the gesture that the system uses to manipulate the cursor.
    /// - Parameter point: The point at which the gesture occurred in your view.
    func beginFloatingCursor(at point: CGPoint) {
        textContainerView.beginFloatingCursor(at: point)
    }

    /// Called to move the floating cursor to a new location.
    /// - Parameter point: The new touch point in the underlying view.
    func updateFloatingCursor(at point: CGPoint) {
        textContainerView.updateFloatingCursor(at: point)
    }

    /// Called at the end of the gesture that the system uses to manipulate the cursor.
    func endFloatingCursor() {
        textContainerView.endFloatingCursor()
    }
}

// MARK: - Editing
public extension TextView {
    /// Returns the text in the specified range.
    /// - Parameter range: A range of text in a document.
    /// - Returns: A substring of a document that falls within the specified range.
    func text(in range: UITextRange) -> String? {
        textContainerView.text(in: range)
    }

    /// Replaces the text in a document that is in the specified range.
    /// - Parameters:
    ///   - range: A range of text in a document.
    ///   - text: A string to replace the text in range.
    func replace(_ range: UITextRange, withText text: String) {
        textContainerView.replace(range, withText: text)
    }

    /// Inserts a character into the displayed text.
    /// - Parameter text: A string object representing the character typed on the system keyboard.
    func insertText(_ text: String) {
        textContainerView.insertText(text)
    }

    /// Deletes a character from the displayed text.
    func deleteBackward() {
        textContainerView.deleteBackward()
    }
}

// MARK: - Selection
public extension TextView {
    /// The range of selected text in a document.
    var selectedTextRange: UITextRange? {
        get {
            textContainerView.selectedTextRange
        }
        set {
            textContainerView.selectedTextRange = newValue
        }
    }

    /// Returns an array of selection rects corresponding to the range of text.
    /// - Parameter range: An object representing a range in a document's text.
    /// - Returns: An array of UITextSelectionRect objects that encompass the selection.
    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        textContainerView.selectionRects(for: range)
    }

    /// Returns the first rectangle that encloses a range of text in a document.
    /// - Parameter range: An object that represents a range of text in a document.
    /// - Returns: The first rectangle in a range of text. You might use this rectangle to draw a correction rectangle. The “first” in the name refers the rectangle enclosing the first line when the range encompasses multiple lines of text.
    func firstRect(for range: UITextRange) -> CGRect {
        textContainerView.firstRect(for: range)
    }
}

// MARK: - Marking
public extension TextView {
    /// A dictionary of attributes that describes how to draw marked text.
    var markedTextStyle: [NSAttributedString.Key: Any]? {
        get {
            textContainerView.markedTextStyle
        }
        set {
            textContainerView.markedTextStyle = newValue
        }
    }

    /// The range of currently marked text in a document.
    var markedTextRange: UITextRange? {
        get {
            textContainerView.markedTextRange
        }
        set {
            textContainerView.markedTextRange = newValue
        }
    }

    /// Inserts the provided text and marks it to indicate that it is part of an active input session.
    /// - Parameters:
    ///   - markedText: The text to be marked.
    ///   - selectedRange: A range within `markedText` that indicates the current selection. This range is always relative to `markedText`.
    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        textContainerView.setMarkedText(markedText, selectedRange: selectedRange)
    }
    
    /// Inserts the provided styled text and marks it to indicate that it is part of an active input session.
    /// - Parameters:
    ///   - markedText: The text to be marked.
    ///   - selectedRange: A range within `markedText` that indicates the current selection. This range is always relative to `markedText`.
    func setAttributedMarkedText(_ markedText: NSAttributedString?, selectedRange: NSRange) {
        textContainerView.setAttributedMarkedText(markedText, selectedRange: selectedRange)
    }

    /// Unmarks the currently marked text.
    func unmarkText() {
        textContainerView.unmarkText()
    }
}

// MARK: - Navigation
public extension TextView {
    /// Returns the range between two text positions.
    /// - Parameters:
    ///   - fromPosition: An object that represents a location in a document.
    ///   - toPosition: An object that represents another location in a document.
    /// - Returns: An object that represents the range between `fromPosition` and `toPosition`.
    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        textContainerView.textRange(from: fromPosition, to: toPosition)
    }

    /// Returns the text position at a specified offset from another text position.
    /// - Parameters:
    ///   - position: A custom UITextPosition object that represents a location in a document.
    ///   - offset: A character offset from position. It can be a positive or negative value.
    /// - Returns: A custom UITextPosition object that represents the location in a document that is at the specified offset from position.
    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        textContainerView.position(from: position, offset: offset)
    }

    /// Returns the text position at a specified offset in a specified direction from another text position.
    /// - Parameters:
    ///   - position: A custom UITextPosition object that represents a location in a document.
    ///   - direction: A UITextLayoutDirection constant that represents the direction of the offset from `position`.
    ///   - offset: A character offset from position.
    /// - Returns: Returns the text position at a specified offset in a specified direction from another text position.
    func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        textContainerView.position(from: position, in: direction, offset: offset)
    }

    /// Returns how one text position compares to another text position.
    /// - Parameters:
    ///   - position: A custom object that represents a location within a document.
    ///   - other: A custom object that represents another location within a document.
    /// - Returns: A value that indicates whether the two text positions are identical or whether one is before the other.
    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        textContainerView.compare(position, to: other)
    }

    /// Returns the number of UTF-16 characters between one text position and another text position.
    /// - Parameters:
    ///   - from: A custom object that represents a location within a document.
    ///   - toPosition: A custom object that represents another location within document.
    /// - Returns: The number of UTF-16 characters between `fromPosition` and `toPosition`.
    func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int {
        textContainerView.offset(from: from, to: toPosition)
    }

    /// Returns the text position that is at the farthest extent in a specified layout direction within a range of text.
    /// - Parameters:
    ///   - range: A text-range object that demarcates a range of text in a document.
    ///   - direction: A constant that indicates a direction of layout (right, left, up, down).
    /// - Returns: A text-position object that identifies a location in the visible text.
    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        textContainerView.position(within: range, farthestIn: direction)
    }

    /// Returns a text range from a specified text position to its farthest extent in a certain direction of layout.
    /// - Parameters:
    ///   - position: A text-position object that identifies a location in a document.
    ///   - direction: A constant that indicates a direction of layout (right, left, up, down).
    /// - Returns: A text-range object that represents the distance from `position` to the farthest extent in `direction`.
    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        textContainerView.characterRange(byExtending: position, in: direction)
    }

    /// Returns the position in a document that is closest to a specified point.
    /// - Parameter point: A point in the view that is drawing a document's text.
    /// - Returns: An object locating a position in a document that is closest to `point`.
    func closestPosition(to point: CGPoint) -> UITextPosition? {
        textContainerView.closestPosition(to: point)
    }

    /// Returns the position in a document that is closest to a specified point in a specified range.
    /// - Parameters:
    ///   - point: A point in the view that is drawing a document's text.
    ///   - range: An object representing a range in a document's text.
    /// - Returns: An object representing the character position in range that is closest to `point`.
    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        textContainerView.closestPosition(to: point, within: range)
    }

    /// Returns the character or range of characters that is at a specified point in a document.
    /// - Parameter point: A point in the view that is drawing a document's text.
    /// - Returns: An object representing a range that encloses a character (or characters) at `point`.
    func characterRange(at point: CGPoint) -> UITextRange? {
        textContainerView.characterRange(at: point)
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
        textContainerView.baseWritingDirection(for: position, in: direction)
    }

    /// Sets the base writing direction for a specified range of text in a document.
    /// - Parameters:
    ///   - writingDirection: A constant that represents a writing direction (for example, left-to-right or right-to-left)
    ///   - range: An object that represents a range of text in a document.
    func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {
        textContainerView.setBaseWritingDirection(writingDirection, for: range)
    }
}
#endif
