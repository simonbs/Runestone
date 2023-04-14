import Combine

struct LineControllerFactory {
    let stringView: CurrentValueSubject<StringView, Never>
    let estimatedLineHeight: EstimatedLineHeight
    let defaultStringAttributes: DefaultStringAttributes
    let typesetSettings: TypesetSettings
    let lineFragmentControllerFactory: LineFragmentControllerFactory
    let syntaxHighlighterFactory: SyntaxHighlighterFactory

    func makeLineController(for line: LineNode) -> LineController {
        let typesetter = LineTypesetter(
            lineID: line.id.rawValue,
            lineBreakMode: typesetSettings.lineBreakMode,
            lineFragmentHeightMultiplier: typesetSettings.lineHeightMultiplier
        )
        return LineController(
            line: line,
            stringView: stringView,
            estimatedLineHeight: estimatedLineHeight,
            tabWidth: typesetSettings.tabWidth,
            typesetter: typesetter,
            defaultStringAttributes: defaultStringAttributes,
            lineFragmentControllerFactory: lineFragmentControllerFactory,
            syntaxHighlighter: syntaxHighlighterFactory.makeSyntaxHighlighter()
        )
    }
}
