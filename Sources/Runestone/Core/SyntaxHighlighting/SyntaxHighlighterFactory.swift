struct SyntaxHighlighterFactory {
    let theme: Theme
    let languageMode: any InternalLanguageMode

    func makeSyntaxHighlighter() -> any SyntaxHighlighter {
        languageMode.createSyntaxHighlighter(with: theme)
    }
}
