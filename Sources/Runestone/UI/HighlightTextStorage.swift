//
//  HighlightTextStorage.swift
//  
//
//  Created by Simon Støvring on 29/11/2020.
//

import UIKit
import TreeSitterBindings
import TreeSitterJSON

final class HighlightTextStorage: NSTextStorage {
    override var string: String {
        return internalString.string
    }

    private let internalString = NSMutableAttributedString()

    override init() {
        super.init()
        tree_sitter_json()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func replaceCharacters(in range: NSRange, with str: String) {
        beginEditing()
        internalString.replaceCharacters(in: range, with: str)
        edited(.editedCharacters, range: range, changeInLength: str.count - range.length)
        endEditing()
    }

    override func setAttributes(_ attrs: [NSAttributedString.Key : Any]?, range: NSRange) {
        beginEditing()
        internalString.setAttributes(attrs, range: range)
        edited(.editedAttributes, range: range, changeInLength: 0)
        endEditing()
    }

    override func attributes(at location: Int, effectiveRange range: NSRangePointer?) -> [NSAttributedString.Key: Any] {
        return internalString.attributes(at: location, effectiveRange: range)
    }

    override func processEditing() {
        super.processEditing()
//        let editedRange = string.convert(self.editedRange)
//        let lineRange = self.lineRange(from: editedRange)
//        let lineNSRange = string.convert(lineRange)
//        internalString.removeAttribute(.foregroundColor, range: lineNSRange)
//        if let tokenizer = tokenizer {
//            let tokens = tokenizer.tokenize(String(string[lineRange]))
//            for token in tokens {
//                let rangeInLine = token.range
//                let rangeInText = NSMakeRange(lineNSRange.location + rangeInLine.location, rangeInLine.length)
//                internalString.addAttributes([.foregroundColor: UIColor.red], range: rangeInText)
//            }
//        }
    }
}

private extension HighlightTextStorage {
    private func lineRange(from range: Range<String.Index>) -> Range<String.Index> {
        var lineStart: String.Index = range.lowerBound
        var lineEnd: String.Index = range.upperBound
        var contentsEnd: String.Index = range.upperBound
        string.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: range)
        return lineStart ..< lineEnd
    }
}
