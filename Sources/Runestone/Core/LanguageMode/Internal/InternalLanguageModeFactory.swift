import _RunestoneTreeSitter
import Combine

struct InternalLanguageModeFactory<
    StringViewType: StringView, LineManagerType: LineManaging
> {
    private let stringView: StringViewType
    private let lineManager: LineManagerType

    init(stringView: StringViewType, lineManager: LineManagerType) {
        self.stringView = stringView
        self.lineManager = lineManager
    }

    func internalLanguageMode(from languageMode: LanguageMode) -> any InternalLanguageMode {
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

//    func internalLanguageMode(from languageModeState: TextViewState.LanguageModeState) -> any InternalLanguageMode {
//        switch languageModeState {
//        case .plainText:
//            return PlainTextInternalLanguageMode()
//        case .treeSitter(let parameters):
//            return TreeSitterInternalLanguageMode(
//                stringView: stringView,
//                lineManager: lineManager,
//                language: parameters.language,
//                languageProvider: parameters.languageProvider,
//                parser: parameters.parser,
//                tree: parameters.tree
//            )
//        }
//    }
}
