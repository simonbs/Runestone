//
//  EditorTextView.swift
//  
//
//  Created by Simon Støvring on 29/11/2020.
//

import UIKit
import RunestoneTextStorage

public protocol EditorTextViewDelegate: UITextViewDelegate {}

open class EditorTextView: UITextView {
    public weak var editorDelegate: EditorTextViewDelegate?
    public var theme: EditorTheme = DefaultEditorTheme() {
        didSet {
            gutterController.theme = theme
            invisibleCharactersController.theme = theme
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
    public var tabSymbol: String {
        get {
            return invisibleCharactersController.tabSymbol
        }
        set {
            invisibleCharactersController.tabSymbol = newValue
        }
    }
    public var spaceSymbol: String {
        get {
            return invisibleCharactersController.spaceSymbol
        }
        set {
            invisibleCharactersController.spaceSymbol = newValue
        }
    }
    public var lineBreakSymbol: String {
        get {
            return invisibleCharactersController.lineBreakSymbol
        }
        set {
            invisibleCharactersController.lineBreakSymbol = newValue
        }
    }
    public var showLineNumbers: Bool {
        get {
            return gutterController.showLineNumbers
        }
        set {
            if newValue != gutterController.showLineNumbers {
                gutterController.showLineNumbers = newValue
                gutterController.updateGutterWidth()
                gutterController.updateExclusionPath()
                setNeedsDisplay()
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
            }
        }
    }
    public var lineNumberFont: UIFont? {
        get {
            return gutterController.lineNumberFont
        }
        set {
            if newValue != gutterController.lineNumberFont {
                gutterController.lineNumberFont = newValue
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
                setNeedsDisplay()
            }
        }
    }
    public var highlightSelectedLine: Bool {
        get {
            return gutterController.highlightSelectedLine
        }
        set {
            if newValue != gutterController.highlightSelectedLine {
                gutterController.highlightSelectedLine = newValue
                invalidateLayoutManager()
            }
        }
    }
    public var tabWidth: CGFloat? {
        didSet {
            if tabWidth != oldValue {
                invalidateLayoutManager()
            }
        }
    }
    open override var delegate: UITextViewDelegate? {
        didSet {
            if isDelegateLockEnabled {
                fatalError("\(type(of: self)) must be the delegate of the UITextView. Please use editorDelegate instead")
            }
        }
    }
    open override var font: UIFont? {
        didSet {
            if font != oldValue {
                invisibleCharactersController.font = font
                editorLayoutManager.font = font
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

    private var isDelegateLockEnabled = false
    private let editorTextStorage = EditorTextStorage()
    private let invisibleCharactersController: EditorInvisibleCharactersController
    private let gutterController: EditorGutterController
    private let editorLayoutManager = EditorLayoutManager()
    private var shouldDrawDummyExtraLineNumber = false

    public init(frame: CGRect = .zero) {
        let textContainer = Self.createTextContainer(layoutManager: editorLayoutManager, textStorage: editorTextStorage)
        gutterController = EditorGutterController(
            layoutManager: editorLayoutManager,
            textStorage: editorTextStorage,
            textContainer: textContainer,
            theme: theme)
        invisibleCharactersController = EditorInvisibleCharactersController(
            layoutManager: editorLayoutManager,
            textStorage: editorTextStorage,
            theme: theme)
        super.init(frame: frame, textContainer: textContainer)
        delegate = self
        isDelegateLockEnabled = true
        editorLayoutManager.delegate = self
        editorLayoutManager.editorDelegate = self
        editorLayoutManager.allowsNonContiguousLayout = true
        invisibleCharactersController.font = font
        invisibleCharactersController.textContainerInset = textContainerInset
        gutterController.delegate = self
        gutterController.lineNumberFont = lineNumberFont
        gutterController.textContainerInset = textContainerInset
        gutterController.updateGutterWidth()
        gutterController.updateExclusionPath()
        updateShouldDrawDummyExtraLineNumber()
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func positionOfLine(containingCharacterAt location: Int) -> LinePosition? {
        if let linePosition = editorTextStorage.positionOfLine(containingCharacterAt: location) {
            return LinePosition(lineNumber: linePosition.lineNumber, column: linePosition.column, length: linePosition.length)
        } else {
            return nil
        }
    }

    public override func responds(to aSelector: Selector!) -> Bool {
        if let editorDelegate = editorDelegate, editorDelegate.responds(to: aSelector) {
            return true
        } else {
            return super.responds(to: aSelector)
        }
    }

    public override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let editorDelegate = editorDelegate, editorDelegate.responds(to: aSelector) {
            return editorDelegate
        } else {
            return super.forwardingTarget(for: aSelector)
        }
    }

    open override func draw(_ rect: CGRect) {
        super.draw(rect)
        gutterController.drawGutterBackground(in: rect)
        if shouldDrawDummyExtraLineNumber {
            gutterController.drawExtraLineIfNecessary()
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

    private func updateShouldDrawDummyExtraLineNumber() {
        // The layoutManager doesn't get a chance to draw backgrounds when the textStorage is empty.
        // That means we won't be showing the first line number. To work around that we draw the first
        // line number in the text view as long as the textStorage is empty.
        // It's probably a bit more expensive but we're not showing any text so it's not that bad.
        let oldValue = shouldDrawDummyExtraLineNumber
        shouldDrawDummyExtraLineNumber = textStorage.length == 0
        if shouldDrawDummyExtraLineNumber != oldValue {
            setNeedsDisplay()
        }
    }

    private func setNeedsDisplayOnSelectionChangeIfNecessary() {
        // Need to redraw for one of two reasons:
        // 1. To remove the selected line behind the "dummy" extra line number.
        // 2. To work around an issue where drawing a background in the NSLayoutManager would sometimes "glitch"
        //     when the textContainer have an exlusionPath. This could be reproduced by enabling highlighting of the
        //     selected line and line numbers, and then adding two lines to the text view and navigating up and
        //     down those two, thereby changing the selected line. The selected line would sometimes be drawn incorrectly.
        if highlightSelectedLine || shouldDrawDummyExtraLineNumber {
            setNeedsDisplay()
        }
    }
}

extension EditorTextView: NSLayoutManagerDelegate {
    public func layoutManager(
        _ layoutManager: NSLayoutManager,
        shouldUse action: NSLayoutManager.ControlCharacterAction,
        forControlCharacterAt charIndex: Int) -> NSLayoutManager.ControlCharacterAction {
        if let tabWidth = tabWidth, tabWidth > 0 {
            let substring = editorTextStorage.substring(in: NSRange(location: charIndex, length: 1))
            return substring == Symbol.tab ? .whitespace : action
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
        guard let tabWidth = tabWidth else {
            return proposedRect
        }
        let substring = editorTextStorage.substring(in: NSRange(location: charIndex, length: 1))
        if substring == Symbol.tab {
            return CGRect(x: proposedRect.minX, y: proposedRect.minY, width: tabWidth, height: proposedRect.height)
        } else {
            return proposedRect
        }
    }

    public func layoutManager(_ layoutManager: NSLayoutManager, didCompleteLayoutFor textContainer: NSTextContainer?, atEnd layoutFinishedFlag: Bool) {
        updateShouldDrawDummyExtraLineNumber()
        if gutterController.shouldUpdateGutterWidth {
            gutterController.updateGutterWidth()
            gutterController.updateExclusionPath()
            // Redraw the gutter to match the new width.
            setNeedsDisplay()
            // Do another layout pass to adjust the placement of the invisible characters.
            invalidateLayoutManager()
        }
    }
}

extension EditorTextView: EditorLayoutManagerDelegate {
    func numberOfLinesIn(_ layoutManager: EditorLayoutManager) -> Int {
        return editorTextStorage.lineCount
    }

    func editorLayoutManagerShouldEnumerateLineFragments(_ layoutManager: EditorLayoutManager) -> Bool {
        return showTabs || showSpaces || showLineBreaks || showLineNumbers
    }

    func editorLayoutManagerDidEnumerateLineFragments(_ layoutManager: EditorLayoutManager) {
        gutterController.drawExtraLineIfNecessary()
    }

    func editorLayoutManager(_ layoutManager: EditorLayoutManager, didEnumerate lineFragment: EditorLineFragment) {
        gutterController.draw(lineFragment)
        invisibleCharactersController.drawInvisibleCharacters(in: lineFragment)
    }
}

extension EditorTextView: EditorGutterControllerDelegate {
    func isTextViewFirstResponder(_ controller: EditorGutterController) -> Bool {
        return isFirstResponder
    }

    func widthOfTextView(_ controller: EditorGutterController) -> CGFloat {
        return bounds.width
    }

    func selectedRangeInTextView(_ controller: EditorGutterController) -> NSRange {
        return selectedRange
    }
}

extension EditorTextView: UITextViewDelegate {
    public func textViewDidBeginEditing(_ textView: UITextView) {
        setNeedsDisplayOnSelectionChangeIfNecessary()
        if highlightSelectedLine {
            invalidateLayoutManager()
        }
        editorDelegate?.textViewDidBeginEditing?(self)
    }

    public func textViewDidEndEditing(_ textView: UITextView) {
        setNeedsDisplayOnSelectionChangeIfNecessary()
        if highlightSelectedLine {
            invalidateLayoutManager()
        }
        editorDelegate?.textViewDidEndEditing?(self)
    }

    public func textViewDidChangeSelection(_ textView: UITextView) {
        setNeedsDisplayOnSelectionChangeIfNecessary()
        editorDelegate?.textViewDidChangeSelection?(self)
    }
}
