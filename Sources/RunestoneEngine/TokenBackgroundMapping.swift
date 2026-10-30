import Foundation

/// Prepares token backgrounds for a separate drawing pass before text overlays.
public enum TokenBackgroundMapping {
    /// Attribute containing a background value for the adapter to paint behind overlays.
    public static let attributeKey = NSAttributedString.Key("runestone_tokenBackgroundColor")

    /// Moves background values to ``attributeKey`` without changing the input string.
    ///
    /// The adapter supplies its platform's background key and paints the resulting
    /// values before search and marked-text overlays. The original input is returned
    /// when it contains no values for the supplied key.
    public static func stringForTypesetting(_ input: NSAttributedString,
                                            backgroundColorKey: NSAttributedString.Key) -> NSAttributedString {
        var copy: NSMutableAttributedString?
        input.enumerateAttribute(backgroundColorKey, in: NSRange(location: 0, length: input.length)) { value, range, _ in
            guard let value else { return }
            if copy == nil {
                copy = NSMutableAttributedString(attributedString: input)
            }
            copy?.removeAttribute(backgroundColorKey, range: range)
            copy?.addAttribute(attributeKey, value: value, range: range)
        }
        return copy ?? input
    }
}
