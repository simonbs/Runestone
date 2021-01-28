//
//  File.swift
//  
//
//  Created by Simon Støvring on 16/01/2021.
//

import Foundation

public final class EditorState {
    let text: String
    let lineManager = LineManager()
    let parser: Parser?

    public init(text: String, language: Language? = nil) {
        self.text = text
        if let language = language {
            parser = Parser(encoding: .utf8)
            parser?.language = language
        } else {
            parser = nil
        }
        prepare()
    }
}

private extension EditorState {
    private func prepare() {
        lineManager.rebuild(from: text as NSString)
        parser?.parse(text)
    }
}
