final class LineControllerFactory {
    private let stringView: StringView
    private let highlightedRangeService: HighlightedRangeService
    private let typesetSettings: TypesetSettings
    private let invisibleCharacterSettings: InvisibleCharacterSettings

    init(
        stringView: StringView,
        highlightedRangeService: HighlightedRangeService,
        typesetSettings: TypesetSettings,
        invisibleCharacterSettings: InvisibleCharacterSettings
    ) {
        self.stringView = stringView
        self.highlightedRangeService = highlightedRangeService
        self.typesetSettings = typesetSettings
        self.invisibleCharacterSettings = invisibleCharacterSettings
    }

    func makeLineController(for line: LineNode) -> LineController {
        LineController(
            line: line,
            stringView: stringView,
            typesetSettings: typesetSettings,
            invisibleCharacterSettings: invisibleCharacterSettings,
            highlightedRangeService: highlightedRangeService
        )
    }
}
