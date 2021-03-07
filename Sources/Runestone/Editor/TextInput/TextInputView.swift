//
//  TextInputView.swift
//  
//
//  Created by Simon Støvring on 05/01/2021.
//

import UIKit

protocol TextInputViewDelegate: AnyObject {
    func textInputViewDidChange(_ view: TextInputView)
    func textInputViewDidChangeSelection(_ view: TextInputView)
    func textInputView(_ view: TextInputView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
    func textInputViewDidInvalidateContentSize(_ view: TextInputView)
    func textInputView(_ view: TextInputView, didProposeContentOffsetAdjustment contentOffsetAdjustment: CGPoint)
    func textInputViewDidUpdateGutterWidth(_ view: TextInputView)
}

final class TextInputView: UIView, UITextInput {
    private struct ParsedLine {
        let startByte: ByteCount
        let byteCount: ByteCount
        var endByte: ByteCount {
            return startByte + byteCount
        }
        let lineRange: NSRange
        let lineString: String
    }

    // MARK: - UITextInput
    var selectedTextRange: UITextRange? {
        get {
            if let range = selectedRange {
                return IndexedRange(range: range)
            } else {
                return nil
            }
        }
        set {
            if let newRange = (newValue as? IndexedRange)?.range {
                if newRange != selectedRange {
                    inputDelegate?.selectionWillChange(self)
                    selectedRange = newRange
                    inputDelegate?.selectionDidChange(self)
                    delegate?.textInputViewDidChangeSelection(self)
                }
            } else {
                selectedRange = nil
            }
        }
    }
    private(set) var markedTextRange: UITextRange?
    var markedTextStyle: [NSAttributedString.Key: Any]?
    var beginningOfDocument: UITextPosition {
        return IndexedPosition(index: 0)
    }
    var endOfDocument: UITextPosition {
        return IndexedPosition(index: string.length)
    }
    var inputDelegate: UITextInputDelegate?
    var hasText: Bool {
        return string.length > 0
    }
    private(set) lazy var tokenizer: UITextInputTokenizer = TextInputStringTokenizer(textInput: self, lineManager: lineManager)
    var autocorrectionType: UITextAutocorrectionType = .default
    var autocapitalizationType: UITextAutocapitalizationType = .sentences
    var smartQuotesType: UITextSmartQuotesType = .default
    var smartDashesType: UITextSmartDashesType = .default
    var smartInsertDeleteType: UITextSmartInsertDeleteType = .default
    var spellCheckingType: UITextSpellCheckingType = .default
    var keyboardType: UIKeyboardType = .default
    var keyboardAppearance: UIKeyboardAppearance = .default
    var returnKeyType: UIReturnKeyType = .default
    @objc var insertionPointColor: UIColor = .black
    @objc var selectionBarColor: UIColor = .black
    @objc var selectionHighlightColor: UIColor = .black
    var isEditing = false {
        didSet {
            if isEditing != oldValue {
                layoutManager.isEditing = isEditing
            }
        }
    }
    override var undoManager: UndoManager? {
        return timedUndoManager
    }

    // MARK: - Appearance
    var theme: EditorTheme = DefaultEditorTheme() {
        didSet {
            lineManager.estimatedLineHeight = estimatedLineHeight
            layoutManager.theme = theme
        }
    }
    var showLineNumbers: Bool {
        get {
            return layoutManager.showLineNumbers
        }
        set {
            layoutManager.showLineNumbers = newValue
            layoutManager.setNeedsLayout()
            setNeedsLayout()
        }
    }
    var showSelectedLines: Bool {
        get {
            return layoutManager.showSelectedLines
        }
        set {
            layoutManager.showSelectedLines = newValue
        }
    }
    var showTabs: Bool {
        get {
            return layoutManager.invisibleCharacterConfiguration.showTabs
        }
        set {
            if newValue != layoutManager.invisibleCharacterConfiguration.showTabs {
                layoutManager.invisibleCharacterConfiguration.showTabs = newValue
                setNeedsLayout()
            }
        }
    }
    var showSpaces: Bool {
        get {
            return layoutManager.invisibleCharacterConfiguration.showSpaces
        }
        set {
            if newValue != layoutManager.invisibleCharacterConfiguration.showSpaces {
                layoutManager.invisibleCharacterConfiguration.showSpaces = newValue
                setNeedsLayout()
            }
        }
    }
    var showLineBreaks: Bool {
        get {
            return layoutManager.invisibleCharacterConfiguration.showLineBreaks
        }
        set {
            if newValue != layoutManager.invisibleCharacterConfiguration.showLineBreaks {
                layoutManager.invisibleCharacterConfiguration.showLineBreaks = newValue
                setNeedsLayout()
            }
        }
    }
    var tabSymbol: String {
        get {
            return layoutManager.invisibleCharacterConfiguration.tabSymbol
        }
        set {
            if newValue != layoutManager.invisibleCharacterConfiguration.tabSymbol {
                layoutManager.invisibleCharacterConfiguration.tabSymbol = newValue
                setNeedsLayout()
            }
        }
    }
    var spaceSymbol: String {
        get {
            return layoutManager.invisibleCharacterConfiguration.spaceSymbol
        }
        set {
            if newValue != layoutManager.invisibleCharacterConfiguration.spaceSymbol {
                layoutManager.invisibleCharacterConfiguration.spaceSymbol = newValue
                setNeedsLayout()
            }
        }
    }
    var lineBreakSymbol: String {
        get {
            return layoutManager.invisibleCharacterConfiguration.lineBreakSymbol
        }
        set {
            if newValue != layoutManager.invisibleCharacterConfiguration.lineBreakSymbol {
                layoutManager.invisibleCharacterConfiguration.lineBreakSymbol = newValue
                setNeedsLayout()
            }
        }
    }
    var indentBehavior: EditorIndentBehavior = .tab
    var gutterLeadingPadding: CGFloat {
        get {
            return layoutManager.gutterLeadingPadding
        }
        set {
            layoutManager.gutterLeadingPadding = newValue
        }
    }
    var gutterTrailingPadding: CGFloat {
        get {
            return layoutManager.gutterTrailingPadding
        }
        set {
            layoutManager.gutterTrailingPadding = newValue
        }
    }
    var textContainerInset: UIEdgeInsets {
        get {
            return layoutManager.textContainerInset
        }
        set {
            layoutManager.textContainerInset = newValue
        }
    }
    var isLineWrappingEnabled: Bool {
        get {
            return layoutManager.isLineWrappingEnabled
        }
        set {
            layoutManager.isLineWrappingEnabled = newValue
        }
    }
    var gutterWidth: CGFloat {
        return layoutManager.gutterWidth
    }
    var lineHeightMultiplier: CGFloat {
        get {
            return layoutManager.lineHeightMultiplier
        }
        set {
            // Notify the delegate that the selection may change as the position of the caret will change when we adjust the height of lines.
            inputDelegate?.selectionWillChange(self)
            layoutManager.lineHeightMultiplier = newValue
            lineManager.estimatedLineHeight = estimatedLineHeight
            inputDelegate?.selectionDidChange(self)
            // Do a layout pass to ensure the position of the caret is correct.
            setNeedsLayout()
            layoutIfNeeded()
        }
    }
    var characterPairs: [EditorCharacterPair] = []
    private var estimatedLineHeight: CGFloat {
        return theme.font.lineHeight * lineHeightMultiplier
    }

    // MARK: - Contents
    weak var delegate: TextInputViewDelegate?
    var string: NSMutableString {
        get {
            return stringView.string
        }
        set {
            if newValue != stringView.string {
                stringView.string = newValue
                lineManager.rebuild(from: newValue)
                layoutManager.invalidateContentSize()
                layoutManager.updateGutterWidth()
            }
        }
    }
    var viewport: CGRect {
        get {
            return layoutManager.viewport
        }
        set {
            if newValue != layoutManager.viewport {
                inputDelegate?.selectionWillChange(self)
                layoutManager.viewport = newValue
                layoutManager.setNeedsLayout()
                setNeedsLayout()
                inputDelegate?.selectionDidChange(self)
            }
        }
    }
    var scrollViewWidth: CGFloat {
        get {
            return layoutManager.scrollViewWidth
        }
        set {
            layoutManager.scrollViewWidth = newValue
        }
    }
    var contentSize: CGSize {
        return layoutManager.contentSize
    }
    private(set) var selectedRange: NSRange? {
        didSet {
            if selectedRange != oldValue {
                layoutManager.selectedRange = selectedRange
                layoutManager.setNeedsLayoutSelection()
                setNeedsLayout()
            }
        }
    }
    override var canBecomeFirstResponder: Bool {
        return true
    }
    weak var editorView: UIView? {
        get {
            return layoutManager.editorView
        }
        set {
            layoutManager.editorView = newValue
        }
    }
    var gutterContainerView: UIView {
        return layoutManager.gutterContainerView
    }
    private(set) var lineManager: LineManager

    // MARK: - Private
    private var stringView = StringView() {
        didSet {
            if stringView !== oldValue {
                lineManager.stringView = stringView
                layoutManager.stringView = stringView
            }
        }
    }
    private var languageMode: LanguageMode = PlainTextLanguageMode() {
        didSet {
            if languageMode !== oldValue {
                if let treeSitterLanguageMode = languageMode as? TreeSitterLanguageMode {
                    treeSitterLanguageMode.delegate = self
                }
            }
        }
    }
    private let timedUndoManager = TimedUndoManager()
    private var markedRange: NSRange?
    private let layoutManager: LayoutManager
    private var parsedLine: ParsedLine?
    private var floatingCaretView: FloatingCaretView?
    private var insertionPointColorBeforeFloatingBegan: UIColor = .black
    private var textSelectionView: UIView? {
        if let klass = NSClassFromString("UITextSelectionView") {
            for subview in subviews {
                if subview.isKind(of: klass) {
                    return subview
                }
            }
        }
        return nil
    }

    // MARK: - Lifecycle
    init() {
        lineManager = LineManager(stringView: stringView)
        layoutManager = LayoutManager(lineManager: lineManager, languageMode: languageMode, stringView: stringView)
        super.init(frame: .zero)
        lineManager.delegate = self
        lineManager.estimatedLineHeight = estimatedLineHeight
        layoutManager.delegate = self
        layoutManager.textInputView = self
        layoutManager.theme = theme
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutManager.layoutIfNeeded()
        layoutManager.layoutSelectionIfNeeded()
    }

    override func copy(_ sender: Any?) {
        if let selectedTextRange = selectedTextRange, let text = text(in: selectedTextRange) {
            UIPasteboard.general.string = text
        }
    }

    override func paste(_ sender: Any?) {
        if let selectedTextRange = selectedTextRange, let string = UIPasteboard.general.string {
            inputDelegate?.selectionWillChange(self)
            replace(selectedTextRange, withText: string)
            inputDelegate?.selectionDidChange(self)
        }
    }

    override func cut(_ sender: Any?) {
        if let selectedTextRange = selectedTextRange, let text = text(in: selectedTextRange) {
            UIPasteboard.general.string = text
            replace(selectedTextRange, withText: "")
        }
    }

    override func selectAll(_ sender: Any?) {
        inputDelegate?.selectionWillChange(self)
        selectedRange = NSRange(location: 0, length: string.length)
        inputDelegate?.selectionDidChange(self)
        delegate?.textInputViewDidChangeSelection(self)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(copy(_:)) || action == #selector(cut(_:)) {
            if let selectedTextRange = selectedTextRange {
                return !selectedTextRange.isEmpty
            } else {
                return false
            }
        } else if action == #selector(paste(_:)) {
            return UIPasteboard.general.hasStrings
        } else if action == #selector(selectAll(_:)) {
            return true
        } else {
            return super.canPerformAction(action, withSender: sender)
        }
    }

    func linePosition(at location: Int) -> LinePosition? {
        return lineManager.linePosition(at: location)
    }

    func setState(_ state: EditorState) {
        stringView = state.stringView
        theme = state.theme
        languageMode = state.languageMode
        lineManager = state.lineManager
        lineManager.delegate = self
        lineManager.estimatedLineHeight = estimatedLineHeight
        layoutManager.languageMode = state.languageMode
        layoutManager.lineManager = state.lineManager
        layoutManager.invalidateContentSize()
        layoutManager.updateGutterWidth()
    }

    func moveCaret(to point: CGPoint) {
        if let index = layoutManager.closestIndex(to: point) {
            selectedTextRange = IndexedRange(location: index, length: 0)
        }
    }

    func setLanguage(_ language: TreeSitterLanguage?, completion: ((Bool) -> Void)? = nil) {
        let newLanguageMode: LanguageMode
        if let language = language {
            newLanguageMode = TreeSitterLanguageMode(language: language, stringView: stringView)
        } else {
            newLanguageMode = PlainTextLanguageMode()
        }
        self.languageMode = newLanguageMode
        layoutManager.languageMode = newLanguageMode
        newLanguageMode.parse(string as String) { [weak self] finished in
            if finished {
                self?.layoutManager.invalidateLines()
                self?.layoutManager.setNeedsLayout()
                self?.setNeedsLayout()
            }
            completion?(finished)
        }
    }

    func syntaxNode(at location: Int) -> SyntaxNode? {
        if let linePosition = lineManager.linePosition(at: location) {
            return languageMode.syntaxNode(at: linePosition)
        } else {
            return nil
        }
    }

    func isIndentation(at location: Int) -> Bool {
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return false
        }
        let localLocation = location - line.location
        guard localLocation >= 0 else {
            return false
        }
        let indentLevel = languageMode.indentLevel(in: line, using: indentBehavior)
        let indentString = indentBehavior.string(indentLevel: indentLevel)
        return localLocation <= indentString.utf16.count
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // We end our current undo group when the user touches the view.
        let result = super.hitTest(point, with: event)
        if result === self {
            timedUndoManager.endUndoGrouping()
        }
        return result
    }
}

// MARK: - Floating Caret
extension TextInputView {
    func beginFloatingCursor(at point: CGPoint) {
        if floatingCaretView == nil, let position = closestPosition(to: point) {
            insertionPointColorBeforeFloatingBegan = insertionPointColor
            insertionPointColor = insertionPointColorBeforeFloatingBegan.withAlphaComponent(0.5)
            updateCaretColor()
            let caretRect = self.caretRect(for: position)
            let caretOrigin = CGPoint(x: point.x - caretRect.width / 2, y: point.y - caretRect.height / 2)
            let floatingCaretView = FloatingCaretView()
            floatingCaretView.backgroundColor = insertionPointColorBeforeFloatingBegan
            floatingCaretView.frame = CGRect(origin: caretOrigin, size: caretRect.size)
            addSubview(floatingCaretView)
            self.floatingCaretView = floatingCaretView
        }
    }

    func updateFloatingCursor(at point: CGPoint) {
        if let floatingCaretView = floatingCaretView {
            let caretSize = floatingCaretView.frame.size
            let caretOrigin = CGPoint(x: point.x - caretSize.width / 2, y: point.y - caretSize.height / 2)
            floatingCaretView.frame = CGRect(origin: caretOrigin, size: caretSize)
        }
    }

    func endFloatingCursor() {
        insertionPointColor = insertionPointColorBeforeFloatingBegan
        updateCaretColor()
        floatingCaretView?.removeFromSuperview()
        floatingCaretView = nil
    }

    private func updateCaretColor() {
        // Removing the UITextSelectionView and re-adding it forces it to query the insertion point color.
        if let textSelectionView = textSelectionView {
            textSelectionView.removeFromSuperview()
            addSubview(textSelectionView)
        }
    }
}

// MARK: - Rects
extension TextInputView {
    func caretRect(for position: UITextPosition) -> CGRect {
        guard let indexedPosition = position as? IndexedPosition else {
            fatalError("Expected position to be of type \(IndexedPosition.self)")
        }
        return layoutManager.caretRect(at: indexedPosition.index)
    }

    func firstRect(for range: UITextRange) -> CGRect {
        guard let indexedRange = range as? IndexedRange else {
            fatalError("Expected range to be of type \(IndexedRange.self)")
        }
        return layoutManager.firstRect(for: indexedRange.range)
    }
}

// MARK: - Editing
extension TextInputView {
    func insertText(_ text: String){
        if let selectedRange = selectedRange, shouldChangeText(in: selectedRange, replacementText: text) {
            if text == Symbol.lineFeed {
                justInsertLineBreak(in: selectedRange)
                layoutIfNeeded()
            } else {
                justInsert(text, in: selectedRange)
                layoutIfNeeded()
            }
        }
    }

    private func justInsertLineBreak(in range: NSRange) {
        if let startLinePosition = lineManager.linePosition(at: range.lowerBound),
           let endLinePosition = lineManager.linePosition(at: range.upperBound),
           let line = lineManager.line(containingCharacterAt: range.lowerBound),
           languageMode.shouldInsertDoubleLineBreak(replacingRangeFrom: startLinePosition, to: endLinePosition) {
            // Cursor is placed between two brackets. Inserting a line break enters a new indentation level.
            // We insert an additional line break to move the closing bracket to a new line and place the
            // cursor in the new block.
            let currentIndentLevel = languageMode.indentLevel(in: line, using: indentBehavior)
            let firstLineText = Symbol.lineFeed + indentBehavior.string(indentLevel: currentIndentLevel + 1)
            let secondLineText = Symbol.lineFeed + indentBehavior.string(indentLevel: currentIndentLevel)
            let indentedText = firstLineText + secondLineText
            justInsert(indentedText, in: range)
            selectedTextRange = IndexedRange(location: range.location + firstLineText.utf16.count, length: 0)
        } else if let line = lineManager.line(containingCharacterAt: range.location) {
            // Indent the new line.
            let localLocation = range.location - line.location
            let currentIndentLevel = languageMode.indentLevel(in: line, using: indentBehavior)
            let suggestedIndentLevel = languageMode.suggestedIndentLevel(at: localLocation, in: line)
            if suggestedIndentLevel < currentIndentLevel {
                // The line have been indented more than the language suggests, so we preserve the current indentation.
                let indentedText = Symbol.lineFeed + indentBehavior.string(indentLevel: currentIndentLevel)
                justInsert(indentedText, in: range)
            } else {
                let indentedText = Symbol.lineFeed + indentBehavior.string(indentLevel: suggestedIndentLevel)
                justInsert(indentedText, in: range)
            }
        } else {
            justInsert(Symbol.lineFeed, in: range)
        }
    }

    private func justInsert(_ text: String, in range: NSRange) {
        let nsText = text as NSString
        let currentText = self.text(in: range) ?? ""
        let newRange = NSRange(location: range.location, length: nsText.length)
        addUndoOperation(replacing: newRange, withText: currentText)
        replaceCharacters(in: range, with: nsText)
        selectedTextRange = IndexedRange(location: newRange.upperBound, length: 0)
    }

    func deleteBackward() {
        guard let selectedRange = selectedRange, selectedRange.length > 0 else {
            return
        }
        let deleteRange: NSRange
        if selectedRange.length == 1, let indentRange = indentRangeInfrontOfLocation(selectedRange.upperBound) {
            deleteRange = indentRange
        } else {
            deleteRange = selectedRange
        }
        if shouldChangeText(in: deleteRange, replacementText: "") {
            if let currentText = text(in: deleteRange) {
                let undoRange = NSRange(location: deleteRange.location, length: 0)
                addUndoOperation(replacing: undoRange, withText: currentText)
            }
            replaceCharacters(in: deleteRange, with: "")
            selectedTextRange = IndexedRange(location: deleteRange.location, length: 0)
            layoutIfNeeded()
        }
    }

    func replace(_ range: UITextRange, withText text: String) {
        if let indexedRange = range as? IndexedRange, shouldChangeText(in: indexedRange.range, replacementText: text) {
            justInsert(text, in: indexedRange.range)
            layoutIfNeeded()
        }
    }

    func indent() {
        if let selectedRange = selectedRange, let line = lineManager.line(containingCharacterAt: selectedRange.location) {
            let currentIndentLevel = languageMode.indentLevel(in: line, using: indentBehavior)
            let suggestedIndentLevel = languageMode.suggestedIndentLevel(for: line)
            if currentIndentLevel < suggestedIndentLevel {
                let startLocation = line.location
                let endLocation = locationOfFirstNonWhitespaceCharacter(in: line)
                let range = NSRange(location: startLocation, length: endLocation - startLocation)
                let indentString = indentBehavior.string(indentLevel: suggestedIndentLevel)
                justInsert(indentString, in: range)
            } else {
                let indentString = indentBehavior.string(indentLevel: 1)
                let startLocation = locationOfFirstNonWhitespaceCharacter(in: line)
                let range = NSRange(location: startLocation, length: 0)
                justInsert(indentString, in: range)
            }
        }
    }

    private func locationOfFirstNonWhitespaceCharacter(in line: DocumentLineNode) -> Int {
        var location = line.location
        let endLocation = location + line.data.length
        let whitespaceCharacters: Set<Character> = [Symbol.Character.space, Symbol.Character.tab]
        while location < endLocation {
            let c = stringView.character(at: location)
            if !whitespaceCharacters.contains(c) {
                break
            } else {
                location += 1
            }
        }
        return location
    }

    func text(in range: UITextRange) -> String? {
        if let indexedRange = range as? IndexedRange {
            return text(in: indexedRange.range)
        } else {
            return nil
        }
    }

    func text(in range: NSRange) -> String? {
        if range.location >= 0 && range.location + range.length <= string.length {
            return string.substring(with: range)
        } else {
            return nil
        }
    }

    private func replaceCharacters(in range: NSRange, with newString: NSString) {
        inputDelegate?.textWillChange(self)
        var editedLines: Set<DocumentLineNode> = []
        justReplaceCharacters(in: range, with: newString, editedLines: &editedLines)
        layoutManager.typeset(editedLines)
        layoutManager.syntaxHighlight(editedLines)
        layoutManager.setNeedsLayout()
        inputDelegate?.textDidChange(self)
        delegate?.textInputViewDidChange(self)
    }

    private func justReplaceCharacters(in range: NSRange, with nsNewString: NSString, editedLines: inout Set<DocumentLineNode>) {
        let byteRange = self.byteRange(from: range)
        let newString = nsNewString as String
        let oldEndLinePosition = lineManager.linePosition(at: range.location + range.length)!
        string.replaceCharacters(in: range, with: newString)
        lineManager.removeCharacters(in: range, editedLines: &editedLines)
        lineManager.insert(nsNewString, at: range.location, editedLines: &editedLines)
        let startLinePosition = lineManager.linePosition(at: range.location)!
        let newEndLinePosition = lineManager.linePosition(at: range.location + nsNewString.length)!
        let textChange = LanguageModeTextChange(
            byteRange: byteRange,
            newString: newString,
            oldEndLinePosition: oldEndLinePosition,
            startLinePosition: startLinePosition,
            newEndLinePosition: newEndLinePosition)
        let result = languageMode.textDidChange(textChange)
        let languageModeEditedLines = result.changedRows.map { lineManager.line(atRow: $0) }
        editedLines.formUnion(languageModeEditedLines)
    }

    private func byteRange(from range: NSRange) -> ByteRange {
        if range.length == 0 {
            let byteOffset = byteOffsetForCharacter(at: range.location)
            return ByteRange(location: byteOffset, length: ByteCount(0))
        } else {
            let startByteOffset = byteOffsetForCharacter(at: range.location)
            let endByteOffset = byteOffsetForCharacter(at: range.location + range.length)
            return ByteRange(from: startByteOffset, to: endByteOffset)
        }
    }

    private func byteOffsetForCharacter(at location: Int) -> ByteCount {
        let line = lineManager.line(containingCharacterAt: location)!
        let lineGlobalRange = NSRange(location: line.location, length: line.value)
        let lineLocalLocation = location - lineGlobalRange.location
        let lineString = string.substring(with: lineGlobalRange)
        let localByteOffset = lineString.byteOffset(at: lineLocalLocation)
        return line.data.startByte + localByteOffset
    }

    private func shouldChangeText(in range: NSRange, replacementText text: String) -> Bool {
        return delegate?.textInputView(self, shouldChangeTextIn: range, replacementText: text) ?? true
    }

    private func addUndoOperation(replacing range: NSRange, withText text: String) {
        timedUndoManager.beginUndoGrouping()
        timedUndoManager.setActionName(L10n.Undo.ActionName.typing)
        timedUndoManager.registerUndo(withTarget: self) { textInputView in
            let indexedRange = IndexedRange(range: range)
            textInputView.justInsert(text, in: indexedRange.range)
            // If we're replacing a range of more than one character with a text of more than one character then we select the new text.
            let textLength = text.utf16.count
            if range.length > 0 && textLength > 0 {
                self.selectedTextRange = IndexedRange(location: range.location, length: textLength)
            }
            self.layoutIfNeeded()
        }
    }
}

// MARK: - Selection
extension TextInputView {
    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        if let indexedRange = range as? IndexedRange {
            return layoutManager.selectionRects(in: indexedRange.range)
        } else {
            return []
        }
    }
}

// MARK: - Marking
extension TextInputView {
    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {}

    func unmarkText() {}
}

// MARK: - Ranges and Positions
extension TextInputView {
    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        return nil
    }

    func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        guard let indexedPosition = position as? IndexedPosition else {
            return nil
        }
        var newPosition = indexedPosition.index
        switch direction {
        case .left:
            newPosition = targetPositionForMoving(fromLocation: indexedPosition.index, by: offset * -1)
        case .right:
            newPosition = targetPositionForMoving(fromLocation: indexedPosition.index, by: offset)
        case .up:
            newPosition = targetPositionForMovingFromLine(containingCharacterAt: indexedPosition.index, lineOffset: offset * -1)
        case .down:
            newPosition = targetPositionForMovingFromLine(containingCharacterAt: indexedPosition.index, lineOffset: offset)
        @unknown default:
            break
        }
        if newPosition >= 0 && newPosition <= string.length {
            return IndexedPosition(index: newPosition)
        } else {
            return nil
        }
    }

    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        return nil
    }

    func characterRange(at point: CGPoint) -> UITextRange? {
        return nil
    }

    func closestPosition(to point: CGPoint) -> UITextPosition? {
        if let index = layoutManager.closestIndex(to: point) {
            return IndexedPosition(index: index)
        } else {
            return nil
        }
    }

    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        return nil
    }

    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        guard let fromIndexedPosition = fromPosition as? IndexedPosition, let toIndexedPosition = toPosition as? IndexedPosition else {
            return nil
        }
        let range = NSRange(location: fromIndexedPosition.index, length: toIndexedPosition.index - fromIndexedPosition.index)
        return IndexedRange(range: range)
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        guard let indexedPosition = position as? IndexedPosition else {
            return nil
        }
        let newPosition = indexedPosition.index + offset
        guard newPosition >= 0 && newPosition <= string.length else {
            return nil
        }
        return IndexedPosition(index: newPosition)
    }

    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        guard let indexedPosition = position as? IndexedPosition, let otherIndexedPosition = other as? IndexedPosition else {
            fatalError("Positions must be of type \(IndexedPosition.self)")
        }
        if indexedPosition.index < otherIndexedPosition.index {
            return .orderedAscending
        } else if indexedPosition.index > otherIndexedPosition.index {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }

    func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int {
        if let fromPosition = from as? IndexedPosition, let toPosition = toPosition as? IndexedPosition {
            return toPosition.index - fromPosition.index
        } else {
            return 0
        }
    }

    private func targetPositionForMoving(fromLocation location: Int, by offset: Int) -> Int {
        let naiveNewLocation = location + offset
        guard naiveNewLocation >= 0 && naiveNewLocation <= string.length else {
            return location
        }
        guard naiveNewLocation > 0 && naiveNewLocation < string.length else {
            return naiveNewLocation
        }
        let range = string.rangeOfComposedCharacterSequence(at: naiveNewLocation)
        guard naiveNewLocation > range.location && naiveNewLocation < range.location + range.length else {
            return naiveNewLocation
        }
        if offset < 0 {
            return location - range.length
        } else {
            return location + range.length
        }
    }

    private func targetPositionForMovingFromLine(containingCharacterAt location: Int, lineOffset: Int) -> Int {
        guard let currentLinePosition = lineManager.linePosition(at: location) else {
            return location
        }
        let targetLineNumber = min(max(currentLinePosition.row + lineOffset, 0), lineManager.lineCount - 1)
        let targetLine = lineManager.line(atRow: targetLineNumber)
        let localLineIndex = min(currentLinePosition.column, targetLine.data.length)
        return targetLine.location + localLineIndex
    }

    // Returns the range of an indentation text if the cursor is placed after an indentation.
    // This can be used when doing a deleteBackward operation to delete an indent level.
    private func indentRangeInfrontOfLocation(_ location: Int) -> NSRange? {
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return nil
        }
        let tabLength = indentBehavior.tabLength
        let localLocation = location - line.location
        guard localLocation >= tabLength else {
            return nil
        }
        let indentLevel = languageMode.indentLevel(in: line, using: indentBehavior)
        let indentString = indentBehavior.string(indentLevel: indentLevel)
        guard localLocation <= indentString.utf16.count else {
            return nil
        }
        guard localLocation % tabLength == 0 else {
            return nil
        }
        return NSRange(location: location - tabLength, length: tabLength)
    }
}

// MARK: - Writing Direction
extension TextInputView {
    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection {
        return .natural
    }

    func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {}
}

// MARK: - LineManagerDelegate
extension TextInputView: LineManagerDelegate {
    func lineManager(_ lineManager: LineManager, didInsert line: DocumentLineNode) {
        timedUndoManager.endUndoGrouping()
        layoutManager.invalidateContentSize()
        layoutManager.updateGutterWidth()
        delegate?.textInputViewDidInvalidateContentSize(self)
    }

    func lineManager(_ lineManager: LineManager, didRemove line: DocumentLineNode) {
        timedUndoManager.endUndoGrouping()
        layoutManager.invalidateContentSize()
        layoutManager.removeLine(withID: line.id)
        layoutManager.updateGutterWidth()
        delegate?.textInputViewDidInvalidateContentSize(self)
    }
}

// MARK: - TreeSitterLanguageModeDeleage
extension TextInputView: TreeSitterLanguageModeDelegate {
    func treeSitterLanguageMode(_ languageMode: TreeSitterLanguageMode, bytesAt byteIndex: ByteCount) -> [Int8]? {
        // Speed up parsing by using the line we recently parsed bytes in when possible.
        if let parsedLine = parsedLine, byteIndex >= parsedLine.startByte && byteIndex < parsedLine.endByte {
            return bytes(at: byteIndex, in: parsedLine)
        } else if let line = lineManager.line(containingByteAt: byteIndex) {
            let startByte = line.data.startByte
            let lineRange = NSRange(location: line.location, length: line.data.totalLength)
            let lineString = string.substring(with: lineRange)
            let parsedLine = ParsedLine(startByte: startByte, byteCount: line.data.byteCount, lineRange: lineRange, lineString: lineString)
            self.parsedLine = parsedLine
            return bytes(at: byteIndex, in: parsedLine)
        } else {
            parsedLine = nil
            return nil
        }
    }

    private func bytes(at byteIndex: ByteCount, in parsedLine: ParsedLine) -> [Int8]? {
        let lineString = parsedLine.lineString
        let localByteIndex = byteIndex - parsedLine.startByte
        let localLocation = lineString.location(from: localByteIndex)
        let globalLocation = parsedLine.lineRange.location + localLocation
        guard globalLocation < string.length else {
            return nil
        }
        let range = string.rangeOfComposedCharacterSequence(at: globalLocation)
        let substring = string.substring(with: range)
        return substring.cString(using: .utf8)?.dropLast()
    }
}

// MARK: - LayoutManagerDelegate
extension TextInputView: LayoutManagerDelegate {
    func layoutManagerDidInvalidateContentSize(_ layoutManager: LayoutManager) {
        delegate?.textInputViewDidInvalidateContentSize(self)
    }

    func layoutManager(_ layoutManager: LayoutManager, didProposeContentOffsetAdjustment contentOffsetAdjustment: CGPoint) {
        delegate?.textInputView(self, didProposeContentOffsetAdjustment: contentOffsetAdjustment)
    }

    func layoutManagerDidUpdateGutterWidth(_ layoutManager: LayoutManager) {
        delegate?.textInputViewDidUpdateGutterWidth(self)
    }
}
