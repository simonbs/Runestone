//
//  TreeSitterSyntaxHighlightToken.swift
//  
//
//  Created by Simon Støvring on 22/01/2021.
//

import UIKit

final class TreeSitterSyntaxHighlightToken {
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

extension TreeSitterSyntaxHighlightToken: Equatable {
    static func == (lhs: TreeSitterSyntaxHighlightToken, rhs: TreeSitterSyntaxHighlightToken) -> Bool {
        return lhs.range == rhs.range && lhs.textColor == rhs.textColor && lhs.font == rhs.font
    }
}

extension TreeSitterSyntaxHighlightToken {
    static func locationSort(_ lhs: TreeSitterSyntaxHighlightToken, _ rhs: TreeSitterSyntaxHighlightToken) -> Bool {
        if lhs.range.location != rhs.range.location {
            return lhs.range.location < rhs.range.location
        } else {
            return lhs.range.length < rhs.range.length
        }
    }
}

extension TreeSitterSyntaxHighlightToken: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[TreeSitterSyntaxHighlightToken: \(range.location) - \(range.length)]"
    }
}
