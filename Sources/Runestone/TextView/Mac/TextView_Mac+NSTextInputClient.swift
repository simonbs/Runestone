#if os(macOS)
import AppKit

extension TextView: NSTextInputClient {
    // swiftlint:disable:next prohibited_super_call
    override public func doCommand(by selector: Selector) {
//        #if DEBUG
//        print(NSStringFromSelector(selector))
//        #endif
        super.doCommand(by: selector)
    }

    /// The current selection range of the text view.
    public func selectedRange() -> NSRange {
//        selectedRangeSubject.value.nonNegativeLength
        return NSRange(location: NSNotFound, length: NSNotFound)
    }

    /// Inserts the given string into the receiver, replacing the specified content.
    /// - Parameters:
    ///   - string: The text to insert.
    ///   - replacementRange: The range of content to replace in the receiver's text storage.
    public func insertText(_ string: Any, replacementRange: NSRange) {
        guard let string = string as? String else {
            return
        }
//        if replacementRange.location == NSNotFound {
//            textInserter.insertText(string)
//        } else {
//            textReplacer.replaceText(in: replacementRange, with: string)
//        }
    }

    /// Inserts the provided text and marks it to indicate that it is part of an active input session.
    /// - Parameters:
    ///   - markedText: The text to be marked.
    ///   - selectedRange: A range within `markedText` that indicates the current selection. This range is always relative to `markedText`.
    public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {}

    /// Unmarks the marked text.
    public func unmarkText() {
//        markedRangeSubject.value = nil
    }

    /// Returns the range of the marked text.
    /// - Returns: The range of marked text or {NSNotFound, 0} if there is no marked range.
    public func markedRange() -> NSRange {
//        markedRangeSubject.value ?? NSRange(location: NSNotFound, length: 0)
        return NSRange(location: NSNotFound, length: NSNotFound)
    }

    /// Returns a Boolean value indicating whether the receiver has marked text.
    /// - Returns: `true` if the receiver has marked text; otherwise `false.
    public func hasMarkedText() -> Bool {
//        (markedRangeSubject.value?.length ?? 0) > 0
        return false
    }

    /// Returns an attributed string derived from the given range in the receiver's text storage.
    /// - Parameters:
    ///   - range: The range in the text storage from which to create the returned string.
    ///   - actualRange: The actual range of the returned string if it was adjusted, for example, to a grapheme cluster boundary or for performance or other reasons. `NULL` if range was not adjusted.
    /// - Returns: The string created from the given range. May return `nil`.
    public func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
        nil
    }

    /// Returns an array of attribute names recognized by the receiver.
    /// - Returns: An array of `NSString` objects representing names for the supported attributes.
    public func validAttributesForMarkedText() -> [NSAttributedString.Key] {
        []
    }

    /// Returns the first logical boundary rectangle for characters in the given range.
    /// - Parameters:
    ///   - range: The character range whose boundary rectangle is returned.
    ///   - actualRange: If non-NULL, contains the character range corresponding to the returned area if it was adjusted, for example, to a grapheme cluster boundary or characters in the first line fragment.
    /// - Returns: The boundary rectangle for the given range of characters, in screen coordinates. The rectangle's `size` value can be negative if the text flows to the left.
    public func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
        .zero
    }

    /// Returns the index of the character whose bounding rectangle includes the given point.
    /// - Parameter point: The point to test, in screen coordinates.
    /// - Returns: The character index, measured from the start of the receiver's text storage, of the character containing the given point.
    public func characterIndex(for point: NSPoint) -> Int {
//        locationRaycaster.location(closestTo: point)
        0
    }
}
#endif
