//
//  EditorTextView.swift
//  
//
//  Created by Simon Støvring on 29/11/2020.
//

import UIKit
import RunestoneTextStorage

open class EditorTextView: UITextView {
    private let highlightTextStorage = HighlightTextStorage()

    public init(frame: CGRect) {
        let textContainer = Self.createTextContainer(textStorage: highlightTextStorage)
        super.init(frame: frame, textContainer: textContainer)
    }

    public init() {
        let textContainer = Self.createTextContainer(textStorage: highlightTextStorage)
        super.init(frame: .zero, textContainer: textContainer)
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public func linePosition(at location: Int) -> LinePosition? {
        if let linePosition = highlightTextStorage.linePosition(at: location) {
            return LinePosition(line: linePosition.line, column: linePosition.column)
        } else {
            return nil
        }
    }
}

private extension EditorTextView {
    private static func createTextContainer(textStorage: NSTextStorage) -> NSTextContainer {
        let layoutManager = LineNumberLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer()
        layoutManager.addTextContainer(textContainer)
        return textContainer
    }
}
