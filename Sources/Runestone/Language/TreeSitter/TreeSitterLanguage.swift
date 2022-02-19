import Foundation
import TreeSitter

/// Language to use for syntax highlighting with Tree-sitter.
///
/// Use a `TreeSitterLanguage` with ``TreeSitterLanguageMode`` to perform syntax highlighting using [Tree-sitter](https://tree-sitter.github.io/tree-sitter/).
///
/// Refer to <doc:AddingATreeSitterLanguage> for more information on adding a Tree-sitter language to your project.
public final class TreeSitterLanguage {
    public let languagePointer: UnsafePointer<TSLanguage>
    public let highlightsQuery: TreeSitterQuery?
    public let injectionsQuery: TreeSitterQuery?
    public let indentationScopes: TreeSitterIndentationScopes?

    public init(_ language: UnsafePointer<TSLanguage>,
                highlightsQuery: TreeSitterQuery? = nil,
                injectionsQuery: TreeSitterQuery? = nil,
                indentationScopes: TreeSitterIndentationScopes? = nil) {
        self.languagePointer = language
        self.highlightsQuery = highlightsQuery
        self.injectionsQuery = injectionsQuery
        self.indentationScopes = indentationScopes
    }
}
