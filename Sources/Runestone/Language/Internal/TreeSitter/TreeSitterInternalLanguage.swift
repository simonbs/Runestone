import TreeSitter

final class TreeSitterInternalLanguage {
    let languagePointer: UnsafePointer<TSLanguage>
    let highlightsQuery: TreeSitterInternalQuery?
    let injectionsQuery: TreeSitterInternalQuery?
    let indentationScopes: TreeSitterIndentationScopes?

    init(_ language: TreeSitterLanguage) {
        self.languagePointer = language.languagePointer
        self.highlightsQuery = Self.internalQuery(string: language.highlightsQuery?.string, language: language.languagePointer)
        self.injectionsQuery = Self.internalQuery(string: language.injectionsQuery?.string, language: language.languagePointer)
        self.indentationScopes = language.indentationScopes
    }
}

private extension TreeSitterInternalLanguage {
    private static func internalQuery(string: String?, language: UnsafePointer<TSLanguage>) -> TreeSitterInternalQuery? {
        if let string = string {
            return try? TreeSitterInternalQuery(source: string, language: language)
        } else {
            return nil
        }
    }
}
