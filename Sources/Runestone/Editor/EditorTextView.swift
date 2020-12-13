//
//  EditorTextView.swift
//  
//
//  Created by Simon Støvring on 29/11/2020.
//

import UIKit
import RunestoneTextStorage

open class EditorTextView: UITextView {
    public var theme: EditorTheme = DefaultEditorTheme() {
        didSet {
            gutterController.theme = theme
        }
    }
    public var showTabs: Bool {
        get {
            return invisibleCharactersController.showTabs
        }
        set {
            if newValue != invisibleCharactersController.showTabs {
                invisibleCharactersController.showTabs = newValue
                invalidateLayoutManager()
            }
        }
    }
    public var showSpaces: Bool {
        get {
            return invisibleCharactersController.showSpaces
        }
        set {
            if newValue != invisibleCharactersController.showSpaces {
                invisibleCharactersController.showSpaces = newValue
                invalidateLayoutManager()
            }
        }
    }
    public var showLineBreaks: Bool {
        get {
            return invisibleCharactersController.showLineBreaks
        }
        set {
            if newValue != invisibleCharactersController.showLineBreaks {
                invisibleCharactersController.showLineBreaks = newValue
                invalidateLayoutManager()
            }
        }
    }
    public var showLineNumbers: Bool {
        get {
            return gutterController.showLineNumbers
        }
        set {
            if newValue != gutterController.showLineNumbers {
                gutterController.showLineNumbers = newValue
                invalidateLayoutManager()
            }
        }
    }
    public var lineNumberLeadingMargin: CGFloat {
        get {
            return gutterController.lineNumberLeadingMargin
        }
        set {
            if newValue != gutterController.lineNumberLeadingMargin {
                gutterController.lineNumberLeadingMargin = newValue
                invalidateLayoutManager()
            }
        }
    }
    public var lineNumberTrailingMargin: CGFloat {
        get {
            return gutterController.lineNumberTrailingMargin
        }
        set {
            if newValue != gutterController.lineNumberTrailingMargin {
                gutterController.lineNumberTrailingMargin = newValue
                invalidateLayoutManager()
            }
        }
    }
    public var accommodateMinimumCharacterCountInLineNumbers: Int {
        get {
            return gutterController.accommodateMinimumCharacterCountInLineNumbers
        }
        set {
            if newValue != gutterController.accommodateMinimumCharacterCountInLineNumbers {
                gutterController.accommodateMinimumCharacterCountInLineNumbers = newValue
                invalidateLayoutManager()
            }
        }
    }
    open override var font: UIFont? {
        didSet {
            if font != oldValue {
                invisibleCharactersController.font = font
            }
        }
    }
    open override var textContainerInset: UIEdgeInsets {
        didSet {
            if textContainerInset != oldValue {
                invisibleCharactersController.textContainerInset = textContainerInset
                gutterController.textContainerInset = textContainerInset
            }
        }
    }

    private let editorTextStorage = EditorTextStorage()
    private let invisibleCharactersController = EditorInvisibleCharactersController()
    private let gutterController: EditorGutterController
    private let editorLayoutManager = EditorLayoutManager()

    public init(frame: CGRect = .zero) {
        let textContainer = Self.createTextContainer(layoutManager: editorLayoutManager, textStorage: editorTextStorage)
        textContainer.widthTracksTextView = true
        gutterController = EditorGutterController(
            layoutManager: editorLayoutManager,
            textStorage: editorTextStorage,
            textContainer: textContainer,
            theme: theme)
        super.init(frame: frame, textContainer: textContainer)
        contentMode = .redraw
        editorTextStorage.editorDelegate = self
        editorLayoutManager.delegate = self
        editorLayoutManager.editorDelegate = self
        editorLayoutManager.allowsNonContiguousLayout = true
        invisibleCharactersController.delegate = self
        invisibleCharactersController.layoutManager = editorLayoutManager
        invisibleCharactersController.font = font
        invisibleCharactersController.textContainerInset = textContainerInset
        gutterController.delegate = self
        gutterController.textContainerInset = textContainerInset
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func positionOfLine(containingCharacterAt location: Int) -> LinePosition? {
        if let linePosition = editorTextStorage.positionOfLine(containingCharacterAt: location) {
            return LinePosition(lineNumber: linePosition.lineNumber, column: linePosition.column)
        } else {
            return nil
        }
    }

    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        gutterController.drawGutter(in: rect)
    }
}

private extension EditorTextView {
    private static func createTextContainer(layoutManager: EditorLayoutManager, textStorage: NSTextStorage) -> NSTextContainer {
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        layoutManager.addTextContainer(textContainer)
        return textContainer
    }

    private func invalidateLayoutManager() {
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        editorLayoutManager.invalidateDisplay(forGlyphRange: glyphRange)
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

extension EditorTextView: EditorTextStorageDelegate {
    public func editorTextStorageDidProcessEditing(_ editorTextStorage: EditorTextStorage) {}

    public func editorTextStorageDidInsertLine(_ editorTextStorage: EditorTextStorage) {
        setNeedsDisplay()
    }

    public func editorTextStorageDidRemoveLine(_ editorTextStorage: EditorTextStorage) {
        setNeedsDisplay()
    }
}

extension EditorTextView: EditorLayoutManagerDelegate {
    func editorLayoutManagerShouldEnumerateLineFragments(_ layoutManager: EditorLayoutManager) -> Bool {
        return showTabs || showSpaces || showLineBreaks || showLineNumbers
    }

    func editorLayoutManager(_ layoutManager: EditorLayoutManager, didEnumerate lineFragment: EditorLineFragment) {
        invisibleCharactersController.drawInvisibleCharacters(in: lineFragment)
    }
}

extension EditorTextView: EditorInvisibleCharactersControllerDelegate {
    func editorInvisibleCharactersController(_ controller: EditorInvisibleCharactersController, substringIn range: NSRange) -> String? {
        return editorTextStorage.substring(with: range)
    }
}

extension EditorTextView: EditorGutterControllerDelegate {
    func numberOfLines(in controller: EditorGutterController) -> Int {
        return editorTextStorage.lineCount
    }

    func editorGutterController(_ controller: EditorGutterController, substringIn range: NSRange) -> String? {
        return editorTextStorage.substring(with: range)
    }
}
