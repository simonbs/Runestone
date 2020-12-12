//
//  EditorTextView.swift
//  
//
//  Created by Simon Støvring on 29/11/2020.
//

import UIKit
import RunestoneTextStorage

open class EditorTextView: UITextView {
    public var showInvisibles = false {
        didSet {
            if showInvisibles != oldValue {
                editorLayoutManager.showInvisibles = showInvisibles
                let glyphRange = layoutManager.glyphRange(for: textContainer)
                editorLayoutManager.invalidateDisplay(forGlyphRange: glyphRange)
            }
        }
    }
    open override var font: UIFont? {
        didSet {
            if font != oldValue {
                editorLayoutManager.font = font
            }
        }
    }
    open override var textContainerInset: UIEdgeInsets {
        didSet {
            if textContainerInset != oldValue {
                editorLayoutManager.textContainerInset = textContainerInset
            }
        }
    }

    private let highlightTextStorage = HighlightTextStorage()
    private let editorLayoutManager = EditorLayoutManager()

    public init(frame: CGRect) {
        let textContainer = Self.createTextContainer(layoutManager: editorLayoutManager, textStorage: highlightTextStorage)
        super.init(frame: frame, textContainer: textContainer)
        initialize()
    }

    public init() {
        let textContainer = Self.createTextContainer(layoutManager: editorLayoutManager, textStorage: highlightTextStorage)
        super.init(frame: .zero, textContainer: textContainer)
        initialize()
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        initialize()
    }

    private func initialize() {
        editorLayoutManager.delegate = self
        editorLayoutManager.font = font
        editorLayoutManager.textContainerInset = textContainerInset
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
    private static func createTextContainer(layoutManager: EditorLayoutManager, textStorage: NSTextStorage) -> NSTextContainer {
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer()
        layoutManager.addTextContainer(textContainer)
        return textContainer
    }
}

extension EditorTextView: NSLayoutManagerDelegate {
    public func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldUse action: NSLayoutManager.ControlCharacterAction,
        forControlCharacterAt charIndex: Int) -> NSLayoutManager.ControlCharacterAction {
        let str = textStorage.string
        let character = str[str.index(str.startIndex, offsetBy: charIndex)]
        if character == Character(Symbol.tab) {
            return .whitespace
        } else {
            return action
        }
    }

    public func layoutManager(
        _ layoutManager: NSLayoutManager,
        boundingBoxForControlGlyphAt glyphIndex: Int,
        for textContainer: NSTextContainer,
        proposedLineFragment proposedRect: CGRect,
        glyphPosition: CGPoint,
        characterIndex charIndex: Int) -> CGRect {
        let str = textStorage.string
        let character = str[str.index(str.startIndex, offsetBy: charIndex)]
        if character == Character(Symbol.tab) {
            let scaledWidth = UIFontMetrics.default.scaledValue(for: 18)
            return CGRect(x: proposedRect.minX, y: proposedRect.minY, width: scaledWidth, height: proposedRect.height)
        } else {
            return proposedRect
        }
    }
}
