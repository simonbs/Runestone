//
//  TreeSitterLanguageMode.swift
//  
//
//  Created by Simon on 27/12/2021.
//

import Foundation

public final class TreeSitterLanguageMode {
    let language: TreeSitterLanguage
    private(set) weak var languageProvider: TreeSitterLanguageProvider?

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
