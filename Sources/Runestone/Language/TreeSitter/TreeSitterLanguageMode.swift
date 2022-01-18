//
//  TreeSitterLanguageMode.swift
//  
//
//  Created by Simon on 27/12/2021.
//

import Foundation

/// Perform syntax highlighting with Tree-sitter.
///
/// Use this language mode to perform syntax highlighting using [Tree-sitter](https://tree-sitter.github.io/tree-sitter/).
///
/// Refer to <doc:AddingATreeSitterLanguage> for more information on adding a Tree-sitter language to your project.
public final class TreeSitterLanguageMode {
    let language: TreeSitterLanguage
    private(set) weak var languageProvider: TreeSitterLanguageProvider?

    /// Create a language mode for the specified Tree-sitter language.
    /// - Parameters:
    ///   - language: Tree-sitter language to use with the language mode.
    ///   - languageProvider: Object that can provide embedded languages on demand.
    public init(language: TreeSitterLanguage, languageProvider: TreeSitterLanguageProvider? = nil) {
        self.language = language
        self.languageProvider = languageProvider
    }
}

extension TreeSitterLanguageMode: LanguageMode {
    func makeInternalLanguageMode(stringView: StringView, lineManager: LineManager) -> InternalLanguageMode {
        return TreeSitterInternalLanguageMode(
            language: language,
            languageProvider: languageProvider,
            stringView: stringView,
            lineManager: lineManager)
    }
}
