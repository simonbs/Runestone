import TreeSitter

final class TreeSitterInternalLanguage {
    let languagePointer: UnsafePointer<TSLanguage>
    let highlightsQuery: TreeSitterQuery?
    let injectionsQuery: TreeSitterQuery?
    let indentationScopes: TreeSitterIndentationScopes?

    init(languagePointer: UnsafePointer<TSLanguage>,
         highlightsQuery: TreeSitterQuery?,
         injectionsQuery: TreeSitterQuery?,
         indentationScopes: TreeSitterIndentationScopes?) {
        self.languagePointer = languagePointer
        self.highlightsQuery = highlightsQuery
        self.injectionsQuery = injectionsQuery
        self.indentationScopes = indentationScopes
    }
}
