import Combine

enum InternalLanguageModeFactory {
    static func internalLanguageMode(
        from languageMode: LanguageMode,
        stringView: CurrentValueSubject<StringView, Never>,
        lineManager: CurrentValueSubject<LineManager, Never>
    ) -> InternalLanguageMode {
        switch languageMode {
        case is PlainTextLanguageMode:
            return PlainTextInternalLanguageMode(
                stringView: stringView.value,
                lineManager: lineManager.value
            )
        case let languageMode as TreeSitterLanguageMode:
            return TreeSitterInternalLanguageMode(
                language: languageMode.language.internalLanguage,
                languageProvider: languageMode.languageProvider,
                stringView: stringView.value,
                lineManager: lineManager.value
            )
        default:
            fatalError("\(languageMode) is not a supported language mode")
        }
    }
}
