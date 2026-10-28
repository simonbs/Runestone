import TreeSitter

final class TreeSitterInternalLanguage {
    let languagePointer: OpaquePointer
    let highlightsQuery: TreeSitterQuery?
    let injectionsQuery: TreeSitterQuery?
    let foldsQuery: TreeSitterQuery?
    let indentationScopes: TreeSitterIndentationScopes?

    init(languagePointer: OpaquePointer,
         highlightsQuery: TreeSitterQuery?,
         injectionsQuery: TreeSitterQuery?,
         indentationScopes: TreeSitterIndentationScopes?,
         foldsQuery: TreeSitterQuery? = nil) {
        self.languagePointer = languagePointer
        self.highlightsQuery = highlightsQuery
        self.injectionsQuery = injectionsQuery
        self.indentationScopes = indentationScopes
        self.foldsQuery = foldsQuery
    }
}
