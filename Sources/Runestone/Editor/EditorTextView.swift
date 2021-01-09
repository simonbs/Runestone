//
//  EditorTextView.swift
//  
//
//  Created by Simon Støvring on 29/11/2020.
//

import UIKit
import RunestoneObjC

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
    public var language: Language? {
        get {
            return parser.language
        }
        set {
            isProcessingNewText = false
            queue.cancelAllOperations()
            parser.reset()
            syntaxHighlightController.removeHighlighting()
            parser.language = newValue
        }
    }
    public var theme: EditorTheme = DefaultEditorTheme() {
        didSet {
            gutterController.theme = theme
            invisibleCharactersController.theme = theme
            syntaxHighlightController.theme = theme
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
                performAndResetContentOffset {
                    gutterController.showLineNumbers = newValue
                    gutterController.updateGutterWidth()
                    gutterController.updateTextContainerInset()
                    setNeedsDisplay()
                }
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
//    public override var text: String! {
//        get {
//            return super.text
//        }
//        set {
//            isProcessingNewText = false
//            queue.cancelAllOperations()
//            parser.reset()
//            syntaxHighlightController.removeHighlighting()
//            super.text = newValue
//        }
//    }
    public override var textColor: UIColor? {
        set {
            syntaxHighlightController.textColor = newValue
        }
        get {
            return syntaxHighlightController.textColor
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
            }
        }
    }
    public var additionalTextContainerInset: UIEdgeInsets {
        get {
            return gutterController.additionalTextContainerInset
        }
        set {
            gutterController.additionalTextContainerInset = newValue
        }
    }

    private var isDelegateLockEnabled = false
    private let lineManager = LineManager()
    private let parser: Parser
    private let syntaxHighlightController: SyntaxHighlightController
    private let editorTextStorage = EditorTextStorage()
    private let invisibleCharactersController: InvisibleCharactersController
    private let gutterController: GutterController
    private let editorLayoutManager: EditorLayoutManager
    private var shouldDrawDummyExtraLineNumber = false
    private let queue = OperationQueue()
    private var highlightedLines = IndexSet()
    private var isProcessingNewText = false

    public init(frame: CGRect = .zero) {
        parser = Parser(encoding: .utf8)
        editorLayoutManager = EditorLayoutManager(textStorage: editorTextStorage)
        syntaxHighlightController = SyntaxHighlightController(parser: parser, textStorage: editorTextStorage, theme: theme)
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
        queue.qualityOfService = .userInitiated
        contentMode = .redraw
        delegate = self
        additionalTextContainerInset = textContainerInset
        isDelegateLockEnabled = true
        lineManager.delegate = self
        parser.delegate = self
        editorTextStorage.editorDelegate = self
        editorLayoutManager.delegate = self
        editorLayoutManager.editorDelegate = self
        editorLayoutManager.allowsNonContiguousLayout = true
        invisibleCharactersController.font = font
        gutterController.textView = self
        gutterController.lineNumberFont = lineNumberFont
        gutterController.updateGutterWidth()
        gutterController.updateTextContainerInset()
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

    public override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        performAndResetContentOffset {
            gutterController.updateGutterWidth()
            gutterController.updateTextContainerInset()
        }
    }
    
    public func linePosition(at location: Int) -> LinePosition? {
        return lineManager.linePosition(at: location)
    }

    public func node(at location: Int) -> Node? {
        return parser.latestTree?.rootNode.namedDescendantInRange(from: UInt32(location), to: UInt32(location))
    }

    public func setText(_ newText: String, completion: ((Bool) -> Void)? = nil) {
        isProcessingNewText = true
        text = newText
        parser.reset()
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let self = self, let operation = operation else {
                completion?(false)
                return
            }
            guard !operation.isCancelled else {
                completion?(false)
                return
            }
            let nsNewText = newText as NSString
            self.lineManager.reset()
            self.lineManager.insert(nsNewText, at: 0)
            self.parser.parse(newText)
            DispatchQueue.main.sync {
                self.isProcessingNewText = false
                if !operation.isCancelled {
                    let range = NSRange(location: 0, length: self.textStorage.length)
                    self.editorTextStorage.beginEditing()
                    self.editorTextStorage.edited(.editedAttributes, range: range, changeInLength: 0)
                    self.editorTextStorage.endEditing()
                }
            }
            completion?(!operation.isCancelled)
        }
        queue.addOperation(operation)
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

    private func updateGutterWidth() {
        if gutterController.shouldUpdateGutterWidth {
            gutterController.updateGutterWidth()
            gutterController.updateTextContainerInset()
            // Redraw the gutter to match the new width.
            setNeedsDisplay()
        }
    }

    private func parseAndHighlight() {
//        let oldTree = parser.latestTree
//        if parser.canParse {
//            parser.parse()
//            highlightChanges(from: oldTree)
//        } else {
//            syntaxHighlightController.removeHighlighting()
//        }
    }

    private func highlightLines(in glyphRange: NSRange) {
        guard syntaxHighlightController.canHighlight else {
            return
        }
        let startLinePosition = lineManager.linePosition(at: glyphRange.location)
        let endLinePosition = lineManager.linePosition(at: glyphRange.location + glyphRange.length)
        if let startLinePosition = startLinePosition, let endLinePosition = endLinePosition {
            let startLineNumber = startLinePosition.lineNumber
            let endLineNumber = endLinePosition.lineNumber
            let isRangeHiglighted = highlightedLines.contains(startLineNumber) && highlightedLines.contains(endLineNumber)
            if !isRangeHiglighted {
                let length = (endLinePosition.lineStartLocation + endLinePosition.length) - startLinePosition.lineStartLocation
                let range = NSRange(location: startLinePosition.lineStartLocation, length: length)
                syntaxHighlightController.highlight([range])
                highlightedLines.insert(integersIn: startLineNumber ... endLineNumber)
            }
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

    private func performAndResetContentOffset(_ block: () -> Void) {
        if bounds != .zero {
            // Attempts to reset the content offset to show the same range of glyphs that were displayed before running the block.
            let initialRange = editorLayoutManager.glyphRange(forBoundingRect: bounds, in: textContainer)
            block()
            let newBounds = editorLayoutManager.boundingRect(forGlyphRange: initialRange, in: textContainer)
            let yOffset = max(-adjustedContentInset.top, newBounds.minY - adjustedContentInset.top)
            contentOffset = CGPoint(x: contentOffset.x, y: yOffset)
        } else {
            block()
        }
    }
}

extension EditorTextView: LineManagerDelegate {
    func lineManager(_ lineManager: LineManager, characterAtLocation location: Int) -> String {
        return editorTextStorage.substring(in: NSRange(location: location, length: 1))!
    }
}

extension EditorTextView: ParserDelegate {
    func parser(_ parser: Parser, substringAtByteIndex byteIndex: uint, point: SourcePoint) -> String? {
        return editorTextStorage.substring(in: NSRange(location: Int(byteIndex), length: 1))
    }
}

extension EditorTextView: EditorTextStorageDelegate {
    public func editorTextStorage(_ editorTextStorage: EditorTextStorage, willReplaceCharactersIn range: NSRange, with string: String) {
        if string.isEmpty && range.length > 0, let linePosition = lineManager.linePosition(at: range.location) {
            let isDeletingLastCharacterInLine = range.location + range.length == linePosition.lineStartLocation + linePosition.length
            let stringTokenizer = tokenizer as? UITextInputStringTokenizer
            stringTokenizer?.sbs_rangeEnclosingPositionReturnsNull = isDeletingLastCharacterInLine
        }
    }

    public func editorTextStorage(_ editorTextStorage: EditorTextStorage, didReplaceCharactersIn range: NSRange, with string: String) {
        guard !isProcessingNewText else {
            return
        }
        let nsString = string as NSString
        let bytesRemoved = range.length
        let bytesAdded = nsString.length
        let oldEndLinePosition = lineManager.linePosition(at: range.location + bytesRemoved)
        lineManager.removeCharacters(in: range)
        lineManager.insert(nsString, at: range.location)
        let startLinePosition = lineManager.linePosition(at: range.location)
        let newEndLinePosition = lineManager.linePosition(at: range.location + bytesAdded)
        if let oldEndLinePosition = oldEndLinePosition, let startLinePosition = startLinePosition, let newEndLinePosition = newEndLinePosition {
            let edit = SimpleInputEdit(
                location: range.location,
                bytesRemoved: bytesRemoved,
                bytesAdded: bytesAdded,
                startLinePosition: startLinePosition,
                oldEndLinePosition: oldEndLinePosition,
                newEndLinePosition: newEndLinePosition)
            parser.apply(edit)
        } else {
            fatalError("Cannot edit syntax tree because one or more line positions are not available")
        }
    }

    public func editorTextStorageDidProcessEditing(_ editorTextStorage: EditorTextStorage) {
        if editorTextStorage.editedMask.contains(.editedCharacters) {
//            parseAndHighlight()
            updateShouldDrawDummyExtraLineNumber()
//            updateGutterWidth()
            DispatchQueue.main.async {
                let stringTokenizer = self.tokenizer as? UITextInputStringTokenizer
                stringTokenizer?.sbs_rangeEnclosingPositionReturnsNull = false
            }
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

    func editorLayoutManager(_ layoutManager: EditorLayoutManager, shouldEnsureLayoutForGlyphRange glyphRange: NSRange) {
        if !isProcessingNewText {
            highlightLines(in: glyphRange)
        }
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
