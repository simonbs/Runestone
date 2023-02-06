final class LineControllerFactory {
    var stringView: StringView

    private let highlightService: HighlightService
    private let invisibleCharacterConfiguration: InvisibleCharacterConfiguration

    init(stringView: StringView, highlightService: HighlightService, invisibleCharacterConfiguration: InvisibleCharacterConfiguration) {
        self.stringView = stringView
        self.highlightService = highlightService
        self.invisibleCharacterConfiguration = invisibleCharacterConfiguration
    }

    func makeLineController(for line: DocumentLineNode) -> LineController {
        LineController(line: line,
                       stringView: stringView,
                       invisibleCharacterConfiguration: invisibleCharacterConfiguration,
                       highlightService: highlightService)
    }
}
