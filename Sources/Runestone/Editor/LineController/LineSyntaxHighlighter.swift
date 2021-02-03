//
//  LineSyntaxHighlighter.swift
//  
//
//  Created by Simon Støvring on 03/02/2021.
//

import Foundation

final class LineSyntaxHighlighter {
    var theme: EditorTheme = DefaultEditorTheme()

    private let syntaxHighlightController: SyntaxHighlightController

    init(syntaxHighlightController: SyntaxHighlightController) {
        self.syntaxHighlightController = syntaxHighlightController
    }

    func setDefaultAttributes(on attributedString: NSMutableAttributedString) {
        let entireRange = NSRange(location: 0, length: attributedString.length)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: theme.textColor,
            .font: theme.font
        ]
        attributedString.setAttributes(attributes, range: entireRange)
    }

    func syntaxHighlight(_ attributedString: NSMutableAttributedString, documentByteRange: ByteRange) {
        if case let .success(captures) = syntaxHighlightController.captures(in: documentByteRange) {
            let tokens = syntaxHighlightController.tokens(for: captures, localTo: documentByteRange)
            setAttributes(for: tokens, on: attributedString)
        }
    }
}

private extension LineSyntaxHighlighter {
    private func setAttributes(for tokens: [SyntaxHighlightToken], on attributedString: NSMutableAttributedString) {
        attributedString.beginEditing()
        let string = attributedString.string
        for token in tokens {
            let range = string.range(from: token.range)
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: token.textColor ?? theme.textColor,
                .font: token.font ?? theme.font
            ]
            attributedString.setAttributes(attributes, range: range)
        }
        attributedString.endEditing()
    }
}
