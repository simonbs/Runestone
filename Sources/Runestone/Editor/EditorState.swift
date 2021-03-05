//
//  EditorState.swift
//  
//
//  Created by Simon Støvring on 16/01/2021.
//

import Foundation

public final class EditorState {
    let text: String
    let stringView: StringView
    let theme: EditorTheme
    let lineManager: LineManager
    let languageMode: LanguageMode

    public init(text: String, theme: EditorTheme, language: TreeSitterLanguage? = nil) {
        self.text = text
        self.theme = theme
        self.stringView = StringView(string: NSMutableString(string: text))
        self.lineManager = LineManager(stringView: stringView)
        if let language = language {
            self.languageMode = TreeSitterLanguageMode(language: language, stringView: stringView)
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
