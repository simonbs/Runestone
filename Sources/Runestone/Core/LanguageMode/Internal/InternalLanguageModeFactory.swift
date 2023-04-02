import Combine

struct InternalLanguageModeFactory {
    private let stringView: CurrentValueSubject<StringView, Never>
    private let lineManager: CurrentValueSubject<LineManager, Never>

    init(stringView: CurrentValueSubject<StringView, Never>, lineManager: CurrentValueSubject<LineManager, Never>) {
        self.stringView = stringView
        self.lineManager = lineManager
    }

    func internalLanguageMode(from languageMode: LanguageMode) -> InternalLanguageMode {
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

    func internalLanguageMode(from languageModeState: TextViewState.LanguageModeState) -> InternalLanguageMode {
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
