import Combine

enum InternalLanguageModeFactory {
    static func internalLanguageMode(
        from languageMode: LanguageMode,
        stringView: CurrentValueSubject<StringView, Never>,
        lineManager: CurrentValueSubject<LineManager, Never>
    ) -> InternalLanguageMode {
        switch languageMode {
        case is PlainTextLanguageMode:
            return PlainTextInternalLanguageMode()
        case let languageMode as TreeSitterLanguageMode:
            return TreeSitterInternalLanguageMode(
                stringView: stringView,
                lineManager: lineManager,
                language: languageMode.language.internalLanguage,
                languageProvider: languageMode.languageProvider
            )
        default:
            fatalError("\(languageMode) is not a supported language mode")
        }
    }

    static func internalLanguageMode(
        from languageModeState: TextViewState.LanguageModeState,
        stringView: CurrentValueSubject<StringView, Never>,
        lineManager: CurrentValueSubject<LineManager, Never>
    ) -> InternalLanguageMode {
        switch languageModeState {
        case .plainText:
            return PlainTextInternalLanguageMode()
        case .treeSitter(let parameters):
            return TreeSitterInternalLanguageMode(
                stringView: stringView,
                lineManager: lineManager,
                language: parameters.language,
                languageProvider: parameters.languageProvider,
                parser: parameters.parser,
                tree: parameters.tree
            )
        }
    }
}
