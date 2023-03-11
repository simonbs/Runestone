import Foundation

extension TextViewState {
    enum LanguageModeState {
        case plainText
        case treeSitter(TreeSitterParameters)
    }
}

extension TextViewState.LanguageModeState {
    struct TreeSitterParameters {
        let language: TreeSitterInternalLanguage
        let languageProvider: TreeSitterLanguageProvider?
        let parser: TreeSitterParser
        let tree: TreeSitterTree?
    }
}
