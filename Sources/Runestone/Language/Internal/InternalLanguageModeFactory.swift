import Foundation

enum InternalLanguageModeFactory {
    static func internalLanguageMode(from languageMode: LanguageMode, stringView: StringView, lineManager: LineManager) -> InternalLanguageMode {
        switch languageMode {
        case is PlainTextLanguageMode:
            return PlainTextInternalLanguageMode()
        case let languageMode as TreeSitterLanguageMode:
            let language = TreeSitterInternalLanguage(languageMode.language)
            return TreeSitterInternalLanguageMode(
                language: language,
                languageProvider: languageMode.languageProvider,
                stringView: stringView,
                lineManager: lineManager)
        default:
            fatalError("\(languageMode) is not a supported language mode")
        }
    }
}
