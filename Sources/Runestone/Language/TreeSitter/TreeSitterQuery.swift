import Foundation
import TreeSitter

/// Used to query the syntax tree created by parsing source code using Tree-sitter.
///
/// Queries are used for syntax highlighting code.
public final class TreeSitterQuery {
    public let string: String?

    public init?(contentsOf fileURL: URL) {
        string = try? String(contentsOf: fileURL)
    }

    public init(string: String) {
        self.string = string
    }
}
