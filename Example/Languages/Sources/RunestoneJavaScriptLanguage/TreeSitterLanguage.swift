import Foundation
import Runestone
import TreeSitterJavaScript

public extension TreeSitterLanguage {
    static var javaScript: TreeSitterLanguage {
        let highlightsQueryURL = queryFileURL(forQueryNamed: "highlights")
        let injectionsQueryURL = queryFileURL(forQueryNamed: "injections")
        let highlightsQuery = TreeSitterLanguage.Query(contentsOf: highlightsQueryURL)
        let injectionsQuery = TreeSitterLanguage.Query(contentsOf: injectionsQueryURL)
        return TreeSitterLanguage(tree_sitter_javascript(),
                                  highlightsQuery: highlightsQuery,
                                  injectionsQuery: injectionsQuery,
                                  indentationScopes: .javaScript)
    }
}

private extension TreeSitterLanguage {
    static func queryFileURL(forQueryNamed queryName: String) -> URL {
        Bundle.module.url(forResource: "queries/" + queryName, withExtension: "scm")!
    }
}
