import Foundation

/// Perform syntax highlighting with Tree-sitter.
///
/// Use this language mode to perform syntax highlighting using [Tree-sitter](https://tree-sitter.github.io/tree-sitter/).
///
/// Refer to <doc:AddingATreeSitterLanguage> for more information on adding a Tree-sitter language to your project.
public final class TreeSitterLanguageMode {
    /// Tree-sitter language to use with the language mode.
    public let language: TreeSitterLanguage
    /// RefeAn object that can provide embedded languages on demand. A strong reference will be stored to the language provider.
    public let languageProvider: TreeSitterLanguageProvider?

    /// Create a language mode for the specified Tree-sitter language.
    /// - Parameters:
    ///   - language: Tree-sitter language to use with the language mode.
    ///   - languageProvider: An object that can provide embedded languages on demand. A strong reference will be stored to the language provider.
    public init(language: TreeSitterLanguage, languageProvider: TreeSitterLanguageProvider? = nil) {
        self.language = language
        self.languageProvider = languageProvider
    }
}

extension TreeSitterLanguageMode: LanguageMode {
    func makeInternalLanguageMode(stringView: StringView, lineManager: LineManager) -> InternalLanguageMode {
        TreeSitterInternalLanguageMode(
            language: language.internalLanguage,
            languageProvider: languageProvider,
            stringView: stringView,
            lineManager: lineManager
        )
    }
}
