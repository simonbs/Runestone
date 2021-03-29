//
//  LineSyntaxHighlighter.swift
//  
//
//  Created by Simon Støvring on 03/02/2021.
//

import Foundation

extension NSAttributedString.Key {
    static let isBold = NSAttributedString.Key("runestone_isBold")
    static let isItalic = NSAttributedString.Key("runestone_isItalic")
}

struct LineSyntaxHiglighterSetAttributesResult {
    let isSizingInvalid: Bool
}

final class LineSyntaxHighlighterInput {
    let attributedString: NSMutableAttributedString
    let byteRange: ByteRange

    init(attributedString: NSMutableAttributedString, byteRange: ByteRange) {
        self.attributedString = attributedString
        self.byteRange = byteRange
    }
}

protocol LineSyntaxHighlighter: AnyObject {
    typealias AsyncCallback = (Result<Void, Error>) -> Void
    var theme: EditorTheme { get set }
    var canHighlight: Bool { get }
    func setDefaultAttributes(on input: LineSyntaxHighlighterInput)
    func syntaxHighlight(_ input: LineSyntaxHighlighterInput)
    func syntaxHighlight(_ input: LineSyntaxHighlighterInput, completion: @escaping AsyncCallback)
    func cancel()
}

extension LineSyntaxHighlighter {
    func setDefaultAttributes(on input: LineSyntaxHighlighterInput) {
        let attributedString = input.attributedString
        let entireRange = NSRange(location: 0, length: attributedString.length)
        let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: theme.textColor, .font: theme.font]
        attributedString.beginEditing()
        attributedString.removeAttribute(.shadow, range: entireRange)
        attributedString.removeAttribute(.font, range: entireRange)
        attributedString.removeAttribute(.foregroundColor, range: entireRange)
        attributedString.removeAttribute(.isBold, range: entireRange)
        attributedString.removeAttribute(.isItalic, range: entireRange)
        attributedString.addAttributes(attributes, range: entireRange)
        attributedString.endEditing()
    }
}
