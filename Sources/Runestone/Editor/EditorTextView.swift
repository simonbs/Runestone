//
//  EditorTextView.swift
//  
//
//  Created by Simon Støvring on 29/11/2020.
//

import UIKit
import RunestoneTextStorage
import TreeSitterLanguages

public protocol EditorTextViewDelegate: UITextViewDelegate {
    func editorTextView(_ textView: EditorTextView, shouldInsert characterPair: EditorCharacterPair, in range: NSRange) -> Bool
}

public extension EditorTextViewDelegate {
    func editorTextView(_ textView: EditorTextView, shouldInsert characterPair: EditorCharacterPair, in range: NSRange) -> Bool {
        return true
    }
}

public final class EditorTextView: UITextView {
    public weak var editorDelegate: EditorTextViewDelegate?
    public var theme: EditorTheme = DefaultEditorTheme() {
        didSet {
            gutterController.theme = theme
            invisibleCharactersController.theme = theme
            syntaxHighlightController.theme = theme
            syntaxHighlightEntireGlyphRange()
        }
    }
    public var showTabs: Bool {
        get {
            return invisibleCharactersController.showTabs
        }
        set {
            if newValue != invisibleCharactersController.showTabs {
                invisibleCharactersController.showTabs = newValue
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
                // Temporarily disable scrolling while we adjust the exclusion path to work around an issue
                // where the UITextVie wwould adjust its content offset when setting the exclusion path.
                isScrollEnabled = false
                gutterController.showLineNumbers = newValue
                gutterController.updateGutterWidth()
                gutterController.updateExclusionPath()
                isScrollEnabled = true
                setNeedsDisplay()
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
            }
        }
    }
    public var tabWidth: CGFloat?
    public var characterPairs: [EditorCharacterPair] = []
    public override var delegate: UITextViewDelegate? {
        didSet {
            if isDelegateLockEnabled {
                if delegate != nil {
                    fatalError("\(type(of: self)) must be the delegate of the UITextView. Please use editorDelegate instead")
                }
            }
        }
    }
    public override var textColor: UIColor? {
        didSet {
            if textColor != oldValue {
                syntaxHighlightController.textColor = textColor
            }
        }
    }
    public override var font: UIFont? {
        didSet {
            if font != oldValue {
                invisibleCharactersController.font = font
                editorLayoutManager.font = font
                syntaxHighlightController.font = font
            }
        }
    }
    public override var textContainerInset: UIEdgeInsets {
        didSet {
            if textContainerInset != oldValue {
                invisibleCharactersController.textContainerInset = textContainerInset
                gutterController.textContainerInset = textContainerInset
            }
        }
    }

    private var isDelegateLockEnabled = false
    private let lineManager = LineManager()
    private let parser: Parser
    private let syntaxHighlightController: SyntaxHighlightController
    private let editorTextStorage = EditorTextStorage()
    private let invisibleCharactersController: InvisibleCharactersController
    private let gutterController: GutterController
    private let editorLayoutManager = EditorLayoutManager()
    private var shouldDrawDummyExtraLineNumber = false

    public init(frame: CGRect = .zero) {
        parser = Parser(encoding: .utf8)
        parser.language = Language(tree_sitter_javascript())
        syntaxHighlightController = SyntaxHighlightController(parser: parser, lineManager: lineManager, textStorage: editorTextStorage, theme: theme)
        let textContainer = Self.createTextContainer(layoutManager: editorLayoutManager, textStorage: editorTextStorage)
        gutterController = GutterController(
            lineManager: lineManager,
            layoutManager: editorLayoutManager,
            textContainer: textContainer,
            textStorage: editorTextStorage,
            theme: theme)
        invisibleCharactersController = InvisibleCharactersController(
            layoutManager: editorLayoutManager,
            textStorage: editorTextStorage,
            theme: theme)
        super.init(frame: frame, textContainer: textContainer)
        contentMode = .redraw
        delegate = self
        isDelegateLockEnabled = true
        lineManager.delegate = self
        parser.delegate = self
        editorTextStorage.editorDelegate = self
        editorLayoutManager.delegate = self
        editorLayoutManager.editorDelegate = self
        editorLayoutManager.allowsNonContiguousLayout = true
        invisibleCharactersController.font = font
        invisibleCharactersController.textContainerInset = textContainerInset
        gutterController.textView = self
        gutterController.lineNumberFont = lineNumberFont
        gutterController.textContainerInset = textContainerInset
        gutterController.updateGutterWidth()
        gutterController.updateExclusionPath()
        syntaxHighlightController.textColor = textColor
        syntaxHighlightController.font = font
        updateShouldDrawDummyExtraLineNumber()
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func draw(_ rect: CGRect) {
        super.draw(rect)
        gutterController.drawGutterBackground(in: rect)
        if shouldDrawDummyExtraLineNumber {
            gutterController.drawExtraLineIfNecessary()
        }
    }
    
    public func positionOfLine(containingCharacterAt location: Int) -> LinePosition? {
        return lineManager.positionOfLine(containingCharacterAt: location)
    }

    public func node(at location: Int) -> Node? {
        return parser.latestTree?.rootNode.namedDescendantInRange(from: UInt32(location), to: UInt32(location))
    }
}

extension EditorTextView {
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
}

private extension EditorTextView {
    private static func createTextContainer(layoutManager: EditorLayoutManager, textStorage: NSTextStorage) -> NSTextContainer {
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer()
        layoutManager.addTextContainer(textContainer)
        return textContainer
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

    private func insert(_ characterPair: EditorCharacterPair, in range: NSRange) {
        guard let selectedTextRange = selectedTextRange else {
            return
        }
        if selectedTextRange.isEmpty {
            insertText(characterPair.leading + characterPair.trailing)
            selectedRange = NSRange(location: range.location + characterPair.leading.count, length: 0)
        } else if let textRange = textRange(from: selectedTextRange.start, to: selectedTextRange.end), let text = text(in: textRange) {
            let modifiedText = characterPair.leading + text + characterPair.trailing
            replace(textRange, withText: modifiedText)
            if let newStartPosition = position(from: textRange.start, offset: characterPair.leading.count) {
                if let newEndPosition = position(from: textRange.end, offset: characterPair.trailing.count) {
                    if let newSelectedTextRange = self.textRange(from: newStartPosition, to: newEndPosition) {
                        self.selectedTextRange = newSelectedTextRange
                    }
                }
            }
        }
    }

    private func syntaxHighlightEntireGlyphRange() {
        textStorage.beginEditing()
        let entireRange = NSRange(location: 0, length: textStorage.length)
        textStorage.edited(.editedAttributes, range: entireRange, changeInLength: 0)
        textStorage.endEditing()
    }

    @discardableResult
    private func syntaxHighlightVisibleLines() -> Bool {
        // Highlight the surrounding lines. Ideally we should get the range of visible glyphs
        // but I haven't found an API that can give the visible glyphs at this point in time.
        let editedRange = editorTextStorage.editedRange
        guard let startLocation = extendLocation(editedRange.location, byLineCount: -20) else {
            return false
        }
        guard let endLocation = extendLocation(editedRange.location + editedRange.length, byLineCount: 20) else {
            return false
        }
        let range = NSRange(location: startLocation, length: endLocation - startLocation)
        syntaxHighlightController.processEditing(range)
        return true
    }

    private func extendLocation(_ location: Int, byLineCount extendingLineCount: Int) -> Int? {
        guard let linePosition = lineManager.positionOfLine(containingCharacterAt: location) else {
            return nil
        }
        let extendedLineNumber = min(max(linePosition.lineNumber + extendingLineCount, 1), lineManager.lineCount)
        let extendedLineLocation = lineManager.locationOfLine(withLineNumber: extendedLineNumber)
        if extendedLineLocation < 0, let extendedLinePosition = lineManager.positionOfLine(containingCharacterAt: extendedLineLocation) {
            return extendedLineLocation + extendedLinePosition.length
        } else {
            return extendedLineLocation
        }
    }
}

extension EditorTextView: LineManagerDelegate {
    func lineManager(_ lineManager: LineManager, characterAtLocation location: Int) -> String {
        return textStorage.attributedSubstring(from: NSRange(location: location, length: 1)).string
    }
}

extension EditorTextView: ParserDelegate {
    func parser(_ parser: Parser, substringAtByteIndex byteIndex: uint, point: SourcePoint) -> String? {
        return editorTextStorage.substring(in: NSRange(location: Int(byteIndex), length: 1))
    }
}

extension EditorTextView: EditorTextStorageDelegate {
    public func editorTextStorage(_ editorTextStorage: EditorTextStorage, didReplaceCharactersIn range: NSRange, with string: String) {
        let nsString = string as NSString
        let bytesRemoved = range.length
        let bytesAdded = nsString.length
        let oldEndLinePosition = lineManager.positionOfLine(containingCharacterAt: range.location + bytesRemoved)
        lineManager.removeCharacters(in: range)
        lineManager.insert(nsString, in: range)
        let startLinePosition = lineManager.positionOfLine(containingCharacterAt: range.location)
        let newEndLinePosition = lineManager.positionOfLine(containingCharacterAt: range.location + bytesAdded)
        if let oldEndLinePosition = oldEndLinePosition, let startLinePosition = startLinePosition, let newEndLinePosition = newEndLinePosition {
            let edit = SyntaxHighlightController.Edit(
                location: range.location,
                bytesRemoved: bytesRemoved,
                bytesAdded: bytesAdded,
                startLinePosition: startLinePosition,
                oldEndLinePosition: oldEndLinePosition,
                newEndLinePosition: newEndLinePosition)
            syntaxHighlightController.apply(edit)
        } else {
            fatalError("Cannot edit syntax tree because one or more line positions are not available")
        }
    }

    public func editorTextStorageDidProcessEditing(_ editorTextStorage: EditorTextStorage) {
        parser.parse()
        if !syntaxHighlightVisibleLines() {
            syntaxHighlightEntireGlyphRange()
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
        }
    }
}

extension EditorTextView: EditorLayoutManagerDelegate {
    func numberOfLinesIn(_ layoutManager: EditorLayoutManager) -> Int {
        return lineManager.lineCount
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

extension EditorTextView: UITextViewDelegate {
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // For some reason this particular delegate call isn't automatically forwarded. Will need to investigate.
        editorDelegate?.scrollViewDidScroll?(scrollView)
    }

    public func textViewDidBeginEditing(_ textView: UITextView) {
        setNeedsDisplayOnSelectionChangeIfNecessary()
        editorDelegate?.textViewDidBeginEditing?(self)
    }

    public func textViewDidEndEditing(_ textView: UITextView) {
        setNeedsDisplayOnSelectionChangeIfNecessary()
        editorDelegate?.textViewDidEndEditing?(self)
    }

    public func textViewDidChangeSelection(_ textView: UITextView) {
        setNeedsDisplayOnSelectionChangeIfNecessary()
        editorDelegate?.textViewDidChangeSelection?(self)
    }

    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if let characterPair = characterPairs.first(where: { $0.leading == text }) {
            let shouldInsertCharacterPair = editorDelegate?.editorTextView(self, shouldInsert: characterPair, in: range) ?? true
            if shouldInsertCharacterPair {
                insert(characterPair, in: range)
                return false
            } else {
                return editorDelegate?.textView?(textView, shouldChangeTextIn: range, replacementText: text) ?? true
            }
        } else {
            return editorDelegate?.textView?(textView, shouldChangeTextIn: range, replacementText: text) ?? true
        }
    }
}
