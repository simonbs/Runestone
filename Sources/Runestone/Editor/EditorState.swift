//
//  File.swift
//  
//
//  Created by Simon Støvring on 16/01/2021.
//

import Foundation

public final class EditorState {
    let text: String
    let theme: EditorTheme
    let lineManager = LineManager()
    let parser: Parser?

    public init(text: String, theme: EditorTheme, language: Language? = nil, encoding: TextEncoding) {
        self.text = text
        self.theme = theme
        if let language = language {
            parser = Parser(encoding: encoding)
            parser?.language = language
        } else {
            parser = nil
        }
        prepare()
    }
}

private extension EditorState {
    private func prepare() {
        lineManager.estimatedLineHeight = theme.font.lineHeight
        lineManager.rebuild(from: text as NSString)
        parser?.parse(text)
    }
}
