//
//  HighlightTextStorage.swift
//  
//
//  Created by Simon Støvring on 29/11/2020.
//

import UIKit

final class HighlightTextStorage: NSTextStorage {
    var language: Language? {
        didSet {
            if language !== oldValue {
                if let language = language {
                    tokenizer = Tokenizer(language: language)
                } else {
                    tokenizer = nil
                }
            }
        }
    }
    override var string: String {
        return internalString.string
    }

    private let internalString = NSMutableAttributedString()
    private var tokenizer: Tokenizer?

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
        let editedRange = string.convert(self.editedRange)
        var lineStart: String.Index = editedRange.lowerBound
        var lineEnd: String.Index = editedRange.upperBound
        var contentsEnd: String.Index = editedRange.upperBound
        string.getLineStart(&lineStart, end: &lineEnd, contentsEnd: &contentsEnd, for: editedRange)
        let lineRange = lineStart ..< lineEnd
        let lineNSRange = string.convert(lineRange)
        internalString.removeAttribute(.foregroundColor, range: lineNSRange)
        if let tokenizer = tokenizer {
            let tokens = tokenizer.tokenize(String(string[lineRange]))
            for token in tokens {
                internalString.addAttributes([.foregroundColor: UIColor.red], range: token.range)
            }
        }
    }
}

private extension String {
    func convert(_ range: NSRange) -> Range<String.Index> {
        return index(startIndex, offsetBy: range.location) ..< index(startIndex, offsetBy: range.location + range.length)
    }

    func convert(_ range: Range<String.Index>) -> NSRange {
        let startLocation = distance(from: startIndex, to: range.lowerBound)
        let endLocation = distance(from: startIndex, to: range.upperBound)
        return NSMakeRange(startLocation, endLocation - startLocation)
    }
}
