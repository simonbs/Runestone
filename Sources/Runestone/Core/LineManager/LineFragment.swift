import CoreText
import Foundation

typealias LineFragmentID = UUID

protocol LineFragment: Equatable {
    var id: LineFragmentID { get }
    /// Index of the line fragment within the line.
    var index: Int { get }
    var location: Int { get }
    var length: Int { get }
    /// The range of the visible characters.
    ///
    /// This range does not contain the hidden characters as defined by ``hiddenLength``.
    var visibleRange: NSRange { get }
    /// The length of the hidden characters.
    ///
    /// Hidden characters are whitespace characters that would be placed at the beginning of the next line fragment if they were rendered. We hide these to align with the behavior of UITextView and NSTextView.
    var hiddenLength: Int { get }
    /// The underlying line.
    var line: CTLine { get }
    /// The lenth of the descent.
    var descent: CGFloat { get }
    /// The non-scaled height of the line fragment.
    var baseSize: CGSize { get }
    /// The scaled height of the line fragment.
    ///
    /// This takes the line height mulitplier into account.
    var scaledSize: CGSize { get }
    /// The y-position of the line fragment.
    ///
    /// This is relative to the beginning of the line.
    var yPosition: CGFloat { get }
    func insertionPointRange(forLineLocalRange lineLocalRange: NSRange) -> NSRange?
}

extension LineFragment {
    /// Entire range of the line fragment.
    ///
    /// The range also contains the ``hiddenLength`` of the line fragment. That is, the visible content of the line fragment is placed in the range `range.location` to `range.length - hiddenLength`.
    var range: NSRange {
        NSRange(location: visibleRange.location, length: visibleRange.length + hiddenLength)
    }
}
