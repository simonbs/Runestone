import UIKit

/// Range of text to highlight.
public final class HighlightedRange {
    /// Unique identifier of the highlighted range.
    public let id: String
    /// Range in the text to highlight.
    public let range: NSRange
    /// Color to highlight the text with.
    public let color: UIColor
    /// Corner radius of the highlight.
    public let cornerRadius: CGFloat

    /// Create a new highlighted range.
    /// - Parameters:
    ///   - id: ID of the range. Defaults to a UUID.
    ///   - range: Range in the text to highlight.
    ///   - color: Color to highlight the text with.
    ///   - cornerRadius: Corner radius of the highlight. A value of zero or less means no corner radius. Defaults to 0.
    public init(id: String = UUID().uuidString, range: NSRange, color: UIColor, cornerRadius: CGFloat = 0) {
        self.id = id
        self.range = range
        self.color = color
        self.cornerRadius = cornerRadius
    }
}

extension HighlightedRange: Equatable {
    public static func == (lhs: HighlightedRange, rhs: HighlightedRange) -> Bool {
        lhs.id == rhs.id && lhs.range == rhs.range && lhs.color == rhs.color
    }
}

extension HighlightedRange: CustomDebugStringConvertible {
    public var debugDescription: String {
        "[HighightedRange range=\(range)]"
    }
}
