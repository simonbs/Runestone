final class LineControllerFactory {
    private let stringView: StringView
    private let highlightedRangeService: HighlightedRangeService
    private let invisibleCharacterConfiguration: InvisibleCharacterConfiguration

    init(
        stringView: StringView,
        highlightedRangeService: HighlightedRangeService,
        invisibleCharacterConfiguration: InvisibleCharacterConfiguration
    ) {
        self.stringView = stringView
        self.highlightedRangeService = highlightedRangeService
        self.invisibleCharacterConfiguration = invisibleCharacterConfiguration
    }

    func makeLineController(for line: LineNode) -> LineController {
        LineController(
            line: line,
            stringView: stringView,
            invisibleCharacterConfiguration: invisibleCharacterConfiguration,
            highlightedRangeService: highlightedRangeService
        )
    }
}
