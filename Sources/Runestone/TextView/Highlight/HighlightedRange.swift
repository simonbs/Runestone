import UIKit

/// The role a highlighted range plays when search results are presented.
public enum HighlightedRangePresentationRole {
    /// An ordinary highlight that is unrelated to search presentation.
    case standard
    /// A search result that is not currently selected.
    case foundSearchResult
    /// The currently selected search result.
    case selectedSearchResult
}

/// Range of text to highlight.
public final class HighlightedRange {
    /// Unique identifier of the highlighted range.
    public let id: String
    /// Range in the text to highlight.
    public let range: NSRange
    /// Color to highlight the text with.
    public let color: UIColor
    /// Optional foreground color for text inside the highlight. A value of `nil` preserves syntax colors.
    public let foregroundColor: UIColor?
    /// Corner radius of the highlight.
    public let cornerRadius: CGFloat
    /// The role of the range when search results are presented.
    public let presentationRole: HighlightedRangePresentationRole

    /// Create a new highlighted range.
    /// - Parameters:
    ///   - id: ID of the range. Defaults to a UUID.
    ///   - range: Range in the text to highlight.
    ///   - color: Color to highlight the text with.
    ///   - foregroundColor: Optional text color inside the highlight. Defaults to `nil`, preserving syntax colors.
    ///   - cornerRadius: Corner radius of the highlight. A value of zero or less means no corner radius. Defaults to 0.
    ///   - presentationRole: Role of the range in search presentation. Defaults to ``HighlightedRangePresentationRole/standard``.
    public init(id: String = UUID().uuidString,
                range: NSRange,
                color: UIColor,
                foregroundColor: UIColor? = nil,
                cornerRadius: CGFloat = 0,
                presentationRole: HighlightedRangePresentationRole = .standard) {
        self.id = id
        self.range = range
        self.color = color
        self.foregroundColor = foregroundColor
        self.cornerRadius = cornerRadius
        self.presentationRole = presentationRole
    }
}

extension HighlightedRange: Equatable {
    public static func == (lhs: HighlightedRange, rhs: HighlightedRange) -> Bool {
        lhs.id == rhs.id
            && lhs.range == rhs.range
            && lhs.color == rhs.color
            && lhs.foregroundColor == rhs.foregroundColor
            && lhs.cornerRadius == rhs.cornerRadius
            && lhs.presentationRole == rhs.presentationRole
    }
}

extension HighlightedRange: CustomDebugStringConvertible {
    public var debugDescription: String {
        "[HighightedRange range=\(range)]"
    }
}
