import Combine

struct SyntaxHighlighterFactory {
    let theme: CurrentValueSubject<Theme, Never>
    let languageMode: CurrentValueSubject<InternalLanguageMode, Never>

    func makeSyntaxHighlighter() -> SyntaxHighlighter {
        languageMode.value.createSyntaxHighlighter(with: theme)
    }
}
