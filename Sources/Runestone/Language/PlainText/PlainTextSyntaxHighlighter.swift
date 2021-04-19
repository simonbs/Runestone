//
//  PlainTextSyntaxHighlighter.swift
//  
//
//  Created by Simon Støvring on 14/02/2021.
//

import Foundation

final class PlainTextSyntaxHighlighter: LineSyntaxHighlighter {
    var theme: Theme = DefaultTheme()
    var canHighlight: Bool {
        return false
    }
    
    func syntaxHighlight(_ input: LineSyntaxHighlighterInput) {}

    func syntaxHighlight(_ input: LineSyntaxHighlighterInput, completion: @escaping AsyncCallback) {
        return completion(.success(()))
    }

    func cancel() {}
}
