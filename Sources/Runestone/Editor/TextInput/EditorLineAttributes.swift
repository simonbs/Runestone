//
//  EditorLineAttributes.swift
//  
//
//  Created by Simon Støvring on 22/01/2021.
//

import UIKit

final class EditorLineAttributes {
    let range: NSRange
    let textColor: UIColor?
    let font: UIFont?
    var isEmpty: Bool {
        return !hasContent
    }
    private var hasContent: Bool {
        return textColor != nil || font != nil
    }

    init(range: NSRange, textColor: UIColor?, font: UIFont?) {
        self.range = range
        self.textColor = textColor
        self.font = font
    }
}

extension EditorLineAttributes: Equatable {
    static func == (lhs: EditorLineAttributes, rhs: EditorLineAttributes) -> Bool {
        return lhs.range == rhs.range && lhs.textColor == rhs.textColor && lhs.font == rhs.font
    }
}

extension EditorLineAttributes {
    static func locationSort(_ lhs: EditorLineAttributes, _ rhs: EditorLineAttributes) -> Bool {
        if lhs.range.location != rhs.range.location {
            return lhs.range.location < rhs.range.location
        } else {
            return lhs.range.length < rhs.range.length
        }
    }
}

extension EditorLineAttributes: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[EditorLineAttributes: \(range.location) - \(range.length)]"
    }
}
