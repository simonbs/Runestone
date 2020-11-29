//
//  HighlightTextStorage.swift
//  
//
//  Created by Simon Støvring on 29/11/2020.
//

import UIKit

final class HighlightTextStorage: NSTextStorage {
    override var string: String {
        return internalString.string
    }

    private let internalString = NSMutableAttributedString()
    private var regularExpression: NSRegularExpression = {
        let pattern = "i[\\p{Alphabetic}&&\\p{Uppercase}][\\p{Alphabetic}]+"
        return try! NSRegularExpression(pattern: pattern, options: [])
    }()

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
        let paragraphRange = string.paragraphRange(for: editedRange)
        let paragraphNSRange = string.convert(paragraphRange)
        removeAttribute(.foregroundColor, range: paragraphNSRange)
        regularExpression.enumerateMatches(in: string, options: [], range: paragraphNSRange) { result, _, _ in
            if let result = result {
                addAttribute(.foregroundColor, value: UIColor.red, range: result.range)
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
