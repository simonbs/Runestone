import CoreText
import Foundation

typealias LineFragmentID = String

protocol LineFragment: Equatable {
    /// The ID of the line fragment.
    var id: LineFragmentID { get }
    /// Index of the line fragment within the line.
    var index: Int { get }
    /// Entire range of the line fragment.
    ///
    /// The range also contains the ``hiddenLength`` of the line fragment. That is, the visible content of the line fragment is placed in the range `range.location` to `range.length - hiddenLength`.
    var range: NSRange { get }
    /// The length of the hidden characters.
    ///
    /// Hidden characters are whitespace characters that would be placed at the beginning of the next line fragment if they were rendered. We hide these to align with the behavior of UITextView and NSTextView.
    var hiddenLength: Int { get }
    /// The underlying line.
    var line: CTLine { get }
    /// The length of the descent.
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
    /// The range of the visible characters.
    ///
    /// This range does not contain the hidden characters as defined by ``hiddenLength``.
    var visibleRange: NSRange {
        NSRange(location: range.location, length: range.length - hiddenLength)
    }
}
