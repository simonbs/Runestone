import Foundation
import TreeSitter

/// Language to use for syntax highlighting with Tree-sitter.
///
/// Use a `TreeSitterLanguage` with ``TreeSitterLanguageMode`` to perform syntax highlighting using [Tree-sitter](https://tree-sitter.github.io/tree-sitter/).
///
/// Refer to <doc:AddingATreeSitterLanguage> for more information on adding a Tree-sitter language to your project.
public final class TreeSitterLanguage {
    /// Reference to the raw Tree-sitter language.
    public let languagePointer: UnsafePointer<TSLanguage>
    /// Query used for syntax highlighting.
    public let highlightsQuery: TreeSitterLanguage.Query?
    /// Query used for detecting injected languages.
    public let injectionsQuery: TreeSitterLanguage.Query?
    /// Rules used for indenting text.
    public let indentationScopes: TreeSitterIndentationScopes?

    var internalLanguage: TreeSitterInternalLanguage {
        prepare()
        if let _internalLanguage = _internalLanguage {
            return _internalLanguage
        } else {
            fatalError("Cannot get internal representation of Tree-sitter language")
        }
    }

    private var isPrepared = false
    private var _internalLanguage: TreeSitterInternalLanguage?

    /// Creates a language to be used with `TreeSitterLanguageMode`.
    /// - Parameters:
    ///   - language: Reference to the raw Tree-sitter language.
    ///   - highlightsQuery: Query used for syntax highlighting.
    ///   - injectionsQuery: Query used for detecting injected languages.
    ///   - indentationScopes: Rules used for indenting text.
    public init(_ language: UnsafePointer<TSLanguage>,
                highlightsQuery: TreeSitterLanguage.Query? = nil,
                injectionsQuery: TreeSitterLanguage.Query? = nil,
                indentationScopes: TreeSitterIndentationScopes? = nil) {
        self.languagePointer = language
        self.highlightsQuery = highlightsQuery
        self.injectionsQuery = injectionsQuery
        self.indentationScopes = indentationScopes
    }

    /// Prepares the language to be used by Runestone. This can be called on a background queue to have the language prepared before it is needed.
    ///
    /// If the language haven't been explicitly prepared, Runestone will automatically do it before it's used.
    public func prepare() {
        if !isPrepared {
            _internalLanguage = TreeSitterInternalLanguage(self)
            isPrepared = true
        }
    }
}

extension TreeSitterLanguage {
    /// A set of patterns to be matched against the syntax tree. Queries are used for syntax highlighting and detecting injected languages.
    ///
    /// Please refer to Tree-sitter's documentation for more information on queries:
    /// https://tree-sitter.github.io/tree-sitter/using-parsers#pattern-matching-with-queries
    public final class Query {
        let string: String?

        /// Creates a query with the contents of a provided file.
        ///
        /// The file at the specified URL is read synchronously when the initializer is called.
        /// - Parameters:
        ///   - fileURL: URL of file to load contents from.
        public init?(contentsOf fileURL: URL) {
            string = try? String(contentsOf: fileURL)
        }

        /// Creates a query with the specified string.
        /// - Parameters:
        ///   - string: Raw representation of the query.
        public init(string: String) {
            self.string = string
        }
    }
}

private extension TreeSitterInternalLanguage {
    // The initializer is kept in an extension in this file to avoid accidentally using it throughout the codebase
    // instead of using the `internalLanguage` property on TreeSitterLanguage.
    convenience init(_ language: TreeSitterLanguage) {
        let highlightsQuery = Self.makeInternalQuery(from: language.highlightsQuery, with: language.languagePointer)
        let injectionsQuery = Self.makeInternalQuery(from: language.injectionsQuery, with: language.languagePointer)
        self.init(languagePointer: language.languagePointer,
                  highlightsQuery: highlightsQuery,
                  injectionsQuery: injectionsQuery,
                  indentationScopes: language.indentationScopes)
    }

    private static func makeInternalQuery(from query: TreeSitterLanguage.Query?, with language: UnsafePointer<TSLanguage>) -> TreeSitterQuery? {
        if let string = query?.string {
            do {
                return try TreeSitterQuery(source: string, language: language)
            } catch {
                #if DEBUG
                print("Invalid TreeSitterLanguage.Query. Error: \(error).")
                #endif
                return nil
            }
        } else {
            return nil
        }
    }
}
