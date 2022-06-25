import Foundation

/// Query to search for in the text view.
///
/// Use the options on the query to specify if the text is a regular expression and if the query should be case sensitive or not.
///
/// When the query contains a regular expression the capture groups can be referred in a replacement text using $0, $1, $2 etc.
public struct SearchQuery: Hashable, Equatable {
    /// Strategy to use when matching the search text against the text in the text view.
    public enum MatchMethod {
        /// Word contains the search text.
        case contains
        /// Word matches the search text.
        case fullWord
        /// Word starts with the search text.
        case startsWith
        /// Word ends with the search text.
        case endsWith
        /// Treat the search text as a regular expression.
        case regularExpression
    }

    /// The text to search for.
    public let text: String
    /// Whether the text is a regular exprssion.
    public let matchMethod: MatchMethod
    /// Whether to perform a case-sensitive search.
    public let isCaseSensitive: Bool

    private var annotatedText: String {
        switch matchMethod {
        case .fullWord:
            return "\\b\(escapedText)\\b"
        case .startsWith:
            return "\\b\(escapedText)"
        case .endsWith:
            return "\(escapedText)\\b"
        case .contains:
            return escapedText
        case .regularExpression:
            return text
        }
    }
    private var escapedText: String {
        return NSRegularExpression.escapedPattern(for: text)
    }
    private var regularExpressionOptions: NSRegularExpression.Options {
        var options: NSRegularExpression.Options = [.anchorsMatchLines]
        if !isCaseSensitive {
            options.insert(.caseInsensitive)
        }
        return options
    }

    /// Creates a query to search for in the text view.
    /// - Parameters:
    ///   - text: The text to search for. May be a regular expression if `isRegularExpression` is `true`.
    ///   - matchMethod: Strategy to use when matching the search text against the text in the text view. Defaults to `contains`.
    ///   - isCaseSensitive: Whether to perform a case-sensitive search.
    public init(text: String, matchMethod: MatchMethod = .contains, isCaseSensitive: Bool = false) {
        self.text = text
        self.matchMethod = matchMethod
        self.isCaseSensitive = isCaseSensitive
    }

    func matches(in string: NSString) -> [NSTextCheckingResult] {
        do {
            let regex = try NSRegularExpression(pattern: annotatedText, options: regularExpressionOptions)
            let range = NSRange(location: 0, length: string.length)
            return regex.matches(in: string as String, range: range)
        } catch {
            #if DEBUG
            print(error)
            #endif
            return []
        }
    }
}
