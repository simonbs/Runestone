import Foundation
import TreeSitter

/// Language to use for syntax highlighting with Tree-sitter.
///
/// Use a `TreeSitterLanguage` with ``TreeSitterLanguageMode`` to perform syntax highlighting using [Tree-sitter](https://tree-sitter.github.io/tree-sitter/).
///
/// Refer to <doc:AddingATreeSitterLanguage> for more information on adding a Tree-sitter language to your project.
public final class TreeSitterLanguage {
    let languagePointer: UnsafePointer<TSLanguage>
    let highlightsQuery: TreeSitterQuery?
    let injectionsQuery: TreeSitterQuery?
    let indentationScopes: TreeSitterIndentationScopes?

    public init(_ language: UnsafePointer<TSLanguage>,
                highlightsQuery: Query? = nil,
                injectionsQuery: Query? = nil,
                indentationScopes: TreeSitterIndentationScopes? = nil) {
        self.languagePointer = language
        self.highlightsQuery = highlightsQuery?.createQuery(with: language)
        self.injectionsQuery = injectionsQuery?.createQuery(with: language)
        self.indentationScopes = indentationScopes
    }
}

extension TreeSitterLanguage {
    public final class Query {
        let string: String?

        public init?(contentsOf fileURL: URL) {
            string = try? String(contentsOf: fileURL)
        }

        public init(string: String) {
            self.string = string
        }

        func createQuery(with language: UnsafePointer<TSLanguage>) -> TreeSitterQuery? {
            if let string = string {
                return try? TreeSitterQuery(source: string, language: language)
            } else {
                return nil
            }
        }
    }
}
