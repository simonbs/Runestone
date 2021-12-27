//
//  PlainTextSyntaxHighlighter.swift
//  
//
//  Created by Simon Støvring on 14/02/2021.
//

import CoreGraphics
import Foundation

final class PlainTextSyntaxHighlighter: LineSyntaxHighlighter {
    var theme: Theme = DefaultTheme()
    var kern: CGFloat = 0
    var canHighlight: Bool {
        return false
    }

    func syntaxHighlight(_ input: LineSyntaxHighlighterInput) {}

    func syntaxHighlight(_ input: LineSyntaxHighlighterInput, completion: @escaping AsyncCallback) {
        return completion(.success(()))
    }

    func cancel() {}
}
