//
//  InternalLanguageModeFactory.swift
//  
//
//  Created by Simon on 27/12/2021.
//

import Foundation

enum InternalLanguageModeFactory {
    static func internalLanguageMode(from languageMode: LanguageMode, stringView: StringView, lineManager: LineManager) -> InternalLanguageMode {
        switch languageMode {
        case is PlainTextLanguageMode:
            return PlainTextInternalLanguageMode()
        case let languageMode as TreeSitterLanguageMode:
            return TreeSitterInternalLanguageMode(
                language: languageMode.language,
                languageProvider: languageMode.languageProvider,
                stringView: stringView,
                lineManager: lineManager)
        default:
            fatalError("\(languageMode) is not a supported language mode")
        }
    }
}
