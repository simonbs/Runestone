//
//  EditorTextView.swift
//  
//
//  Created by Simon Støvring on 29/11/2020.
//

import UIKit
import RunestoneTextStorage

open class EditorTextView: UITextView {
    public var showTabs = false {
        didSet {
            if showTabs != oldValue {
                invisibleCharactersController.showTabs = showTabs
                invalidateLayoutManager()
            }
        }
    }
    public var showSpaces = false {
        didSet {
            if showSpaces != oldValue {
                invisibleCharactersController.showSpaces = showSpaces
                invalidateLayoutManager()
            }
        }
    }
    public var showLineBreaks = false {
        didSet {
            if showLineBreaks != oldValue {
                invisibleCharactersController.showLineBreaks = showLineBreaks
                invalidateLayoutManager()
            }
        }
    }
    public var lineNumbersFont: UIFont = .systemFont(ofSize: 14) {
        didSet {
            if lineNumbersFont != oldValue {
                gutterController.lineNumbersFont = lineNumbersFont
            }
        }
    }
    public var showLineNumbers = false {
        didSet {
            if showLineNumbers != oldValue {
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
            }
        }
    }

    private let editorTextStorage = EditorTextStorage()
    private let invisibleCharactersController = EditorInvisibleCharactersController()
    private let gutterController = EditorGutterController()
    private let editorLayoutManager = EditorLayoutManager()

    public init(frame: CGRect = .zero) {
        let textContainer = Self.createTextContainer(layoutManager: editorLayoutManager, textStorage: editorTextStorage)
        super.init(frame: frame, textContainer: textContainer)
        editorTextStorage.editorDelegate = self
        editorLayoutManager.delegate = self
        editorLayoutManager.editorDelegate = self
        invisibleCharactersController.delegate = self
        invisibleCharactersController.layoutManager = editorLayoutManager
        invisibleCharactersController.font = font
        invisibleCharactersController.textContainerInset = textContainerInset
        gutterController.lineNumbersFont = lineNumbersFont
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func linePosition(at location: Int) -> LinePosition? {
        if let linePosition = editorTextStorage.linePosition(at: location) {
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
    public func editorTextStorageDidProcessEditing(_ editorTextStorage: EditorTextStorage) {
        
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
    func editorInvisibleCharactersController(_ controller: EditorInvisibleCharactersController, substringIn range: NSRange) -> String {
        return editorTextStorage.substring(with: range)
    }
}
