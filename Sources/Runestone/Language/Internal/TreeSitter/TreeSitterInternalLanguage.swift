import TreeSitter

final class TreeSitterInternalLanguage {
    let languagePointer: UnsafePointer<TSLanguage>
    let highlightsQuery: TreeSitterQuery?
    let injectionsQuery: TreeSitterQuery?
    let indentationScopes: TreeSitterIndentationScopes?

    init(_ language: TreeSitterLanguage) {
        self.languagePointer = language.languagePointer
        self.highlightsQuery = Self.makeInternalQuery(from: language.highlightsQuery, with: language.languagePointer)
        self.injectionsQuery = Self.makeInternalQuery(from: language.injectionsQuery, with: language.languagePointer)
        self.indentationScopes = language.indentationScopes
    }
}

private extension TreeSitterInternalLanguage {
    private static func makeInternalQuery(from query: TreeSitterLanguage.Query?, with language: UnsafePointer<TSLanguage>) -> TreeSitterQuery? {
        if let string = query?.string {
            return try? TreeSitterQuery(source: string, language: language)
        } else {
            return nil
        }
    }
}
