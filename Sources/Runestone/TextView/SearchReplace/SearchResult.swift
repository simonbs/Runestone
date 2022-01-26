import Foundation

/// A match returned by performing a search query.
public struct SearchResult: Hashable, Equatable {
    /// Unique identifier of the result.
    public let id: String = UUID().uuidString
    /// Range of the matched text.
    public let range: NSRange
    /// Location of line on which the matched text starts.
    public let startLocation: TextLocation
    /// Location of line on which the matched text ends.
    public let endLocation: TextLocation
}
