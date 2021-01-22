//
//  SyntaxHighlightToken.swift
//  
//
//  Created by Simon Støvring on 22/01/2021.
//

import UIKit

final class SyntaxHighlightToken {
    let range: ByteRange
    let textColor: UIColor?
    let font: UIFont?
    var isEmpty: Bool {
        return !hasContent
    }
    private var hasContent: Bool {
        return textColor != nil || font != nil
    }

    init(range: ByteRange, textColor: UIColor?, font: UIFont?) {
        self.range = range
        self.textColor = textColor
        self.font = font
    }
}

extension SyntaxHighlightToken: Equatable {
    static func == (lhs: SyntaxHighlightToken, rhs: SyntaxHighlightToken) -> Bool {
        return lhs.range == rhs.range && lhs.textColor == rhs.textColor && lhs.font == rhs.font
    }
}

extension SyntaxHighlightToken {
    static func locationSort(_ lhs: SyntaxHighlightToken, _ rhs: SyntaxHighlightToken) -> Bool {
        if lhs.range.location != rhs.range.location {
            return lhs.range.location < rhs.range.location
        } else {
            return lhs.range.length < rhs.range.length
        }
    }
}

extension SyntaxHighlightToken: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[SyntaxHighlightToken: \(range.location) - \(range.length)]"
    }
}
