//
//  SyntaxHighlightToken.swift
//  
//
//  Created by Simon Støvring on 22/01/2021.
//

import UIKit
import RunestoneUtils

final class SyntaxHighlightToken {
    let range: ByteRange
    let textColor: UIColor?
    let font: UIFont?
    let shadow: NSShadow?
    var isEmpty: Bool {
        return range.length == ByteCount(0) || (textColor == nil && font == nil && shadow == nil)
    }

    init(range: ByteRange, textColor: UIColor?, font: UIFont?, shadow: NSShadow?) {
        self.range = range
        self.textColor = textColor
        self.font = font
        self.shadow = shadow
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
