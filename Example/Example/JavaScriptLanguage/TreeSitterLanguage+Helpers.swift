import Foundation
import Runestone
import TreeSitterJavaScript
import TreeSitterJavaScriptQueries

public extension TreeSitterLanguage {
    static var javaScript: TreeSitterLanguage {
        let highlightsQuery = TreeSitterLanguage.Query(contentsOf: TreeSitterJavaScriptQueries.Query.highlightsFileURL)
        let injectionsQuery = TreeSitterLanguage.Query(contentsOf: TreeSitterJavaScriptQueries.Query.injectionsFileURL)
        return TreeSitterLanguage(tree_sitter_javascript(),
                                  highlightsQuery: highlightsQuery,
                                  injectionsQuery: injectionsQuery,
                                  indentationScopes: .javaScript)
    }
}
