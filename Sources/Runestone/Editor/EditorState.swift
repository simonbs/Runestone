//
//  EditorState.swift
//  
//
//  Created by Simon Støvring on 16/01/2021.
//

import Foundation

public final class EditorState {
    let text: String
    let theme: EditorTheme
    let lineManager = LineManager()
    let languageMode: LanguageMode

    public init(text: String, theme: EditorTheme, language: TreeSitterLanguage? = nil) {
        self.text = text
        self.theme = theme
        if let language = language {
            self.languageMode = TreeSitterLanguageMode(language)
        } else {
            self.languageMode = PlainTextLanguageMode()
        }
        prepare()
    }
}

private extension EditorState {
    private func prepare() {
        lineManager.estimatedLineHeight = theme.font.lineHeight
        lineManager.rebuild(from: text as NSString)
        languageMode.parse(text)
    }
}
