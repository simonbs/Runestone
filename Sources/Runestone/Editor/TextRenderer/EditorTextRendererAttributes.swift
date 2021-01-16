//
//  EditorTextRendererAttributes.swift
//  
//
//  Created by Simon Støvring on 16/01/2021.
//

import UIKit

final class EditorTextRendererAttributes {
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

extension EditorTextRendererAttributes: Equatable {
    static func == (lhs: EditorTextRendererAttributes, rhs: EditorTextRendererAttributes) -> Bool {
        return lhs.range == rhs.range && lhs.textColor == rhs.textColor && lhs.font == rhs.font
    }
}

extension EditorTextRendererAttributes: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[EditorTextRendererAttributes: \(range.location) - \(range.length)]"
    }
}
