import Combine

struct SyntaxHighlighterFactory {
    let theme: CurrentValueSubject<Theme, Never>
    let languageMode: CurrentValueSubject<any InternalLanguageMode, Never>

    func makeSyntaxHighlighter() -> any SyntaxHighlighter {
        languageMode.value.createSyntaxHighlighter(with: theme)
    }
}
