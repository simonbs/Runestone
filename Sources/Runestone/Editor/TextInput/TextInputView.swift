//
//  TextInputView.swift
//  
//
//  Created by Simon Støvring on 05/01/2021.
//

import UIKit

protocol TextInputViewDelegate: AnyObject {
    func textInputViewDidBeginEditing(_ view: TextInputView)
    func textInputViewDidEndEditing(_ view: TextInputView)
    func textInputViewDidChange(_ view: TextInputView)
    func textInputViewDidChangeSelection(_ view: TextInputView)
    func textInputView(_ view: TextInputView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
    func textInputViewDidInvalidateContentSize(_ view: TextInputView)
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

    // MARK: - Appearance
    var theme: EditorTheme = DefaultEditorTheme() {
        didSet {
            lineManager.estimatedLineHeight = theme.font.lineHeight
            layoutManager.theme = theme
            syntaxHighlightController.theme = theme
        }
    }
    var language: Language? {
        set {
            operationQueue.cancelAllOperations()
            _language = newValue
            parse(with: newValue)
            layoutManager.invalidateAllLines()
            layoutManager.setNeedsLayout()
            setNeedsLayout()
        }
        get {
            return _language
        }
    }
    override var backgroundColor: UIColor? {
        didSet {
            if backgroundColor != oldValue {
                layoutManager.backgroundColor = backgroundColor
            }
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
    var gutterMargin: CGFloat {
        get {
            return layoutManager.gutterMargin
        }
        set {
            layoutManager.gutterMargin = newValue
        }
    }

    // MARK: - Contents
    weak var delegate: TextInputViewDelegate?
    var string: NSMutableString {
        get {
            return _string
        }
        set {
            if _string != newValue {
                _string = newValue
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
    override var frame: CGRect {
        didSet {
            if frame != oldValue {
                layoutManager.frame = frame
            }
        }
    }
    var contentSize: CGSize {
        return layoutManager.contentSize
    }
    private(set) var selectedRange: NSRange?
    override var canBecomeFirstResponder: Bool {
        return true
    }

    // MARK: - Private
    private var _string = NSMutableString()
    private var _language: Language?
    private let operationQueue = OperationQueue()
    private var markedRange: NSRange?
    private var lineManager = LineManager()
    private let syntaxHighlightController = SyntaxHighlightController()
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
        operationQueue.name = "Runestone"
        operationQueue.qualityOfService = .userInitiated
        layoutManager = LayoutManager(lineManager: lineManager, syntaxHighlightController: syntaxHighlightController, operationQueue: operationQueue)
        super.init(frame: .zero)
        lineManager.delegate = self
        lineManager.estimatedLineHeight = theme.font.lineHeight
        layoutManager.delegate = self
        layoutManager.containerView = self
        layoutManager.theme = theme
        layoutManager.backgroundColor = backgroundColor
        syntaxHighlightController.theme = theme
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutManager.layoutIfNeeded()
    }

    @discardableResult
    override func becomeFirstResponder() -> Bool {
        let wasFirstResponder = isFirstResponder
        let didBecomeFirstResponder = super.becomeFirstResponder()
        if !wasFirstResponder && isFirstResponder {
            markedRange = nil
            if selectedRange == nil {
                inputDelegate?.selectionWillChange(self)
                selectedRange = NSRange(location: 0, length: 0)
                inputDelegate?.selectionDidChange(self)
            }
            delegate?.textInputViewDidBeginEditing(self)
        }
        return didBecomeFirstResponder
    }

    @discardableResult
    override func resignFirstResponder() -> Bool {
        let wasFirstResponder = isFirstResponder
        let didResignFirstResponder = super.resignFirstResponder()
        if wasFirstResponder && !isFirstResponder {
            inputDelegate?.selectionWillChange(self)
            selectedRange = nil
            markedRange = nil
            inputDelegate?.selectionDidChange(self)
        }
        return didResignFirstResponder
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

    override func selectAll(_ sender: Any?) {
        inputDelegate?.selectionWillChange(self)
        selectedRange = NSRange(location: 0, length: string.length)
        inputDelegate?.selectionDidChange(self)
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(copy(_:)) {
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
        _string = NSMutableString(string: state.text)
        lineManager = state.lineManager
        lineManager.delegate = self
        syntaxHighlightController.parser = state.parser
        syntaxHighlightController.parser?.delegate = self
        layoutManager.lineManager = state.lineManager
        layoutManager.invalidateContentSize()
        layoutManager.updateGutterWidth()
    }

    func moveCaret(to point: CGPoint) {
        if let index = layoutManager.closestIndex(to: point) {
            inputDelegate?.selectionWillChange(self)
            selectedRange = NSRange(location: index, length: 0)
            inputDelegate?.selectionDidChange(self)
        }
    }

    func setLanguage(_ language: Language?, completion: ((Bool) -> Void)? = nil) {
        operationQueue.cancelAllOperations()
        _language = language
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak operation, weak self] in
            if let self = self, let operation = operation, !operation.isCancelled {
                self.parse(with: language)
                DispatchQueue.main.sync {
                    if !operation.isCancelled {
                        self.layoutManager.invalidateAllLines()
                        self.layoutManager.setNeedsLayout()
                        self.setNeedsLayout()
                        completion?(true)
                    } else {
                        completion?(false)
                    }
                }
            } else {
                DispatchQueue.main.sync {
                    completion?(false)
                }
            }
        }
        operationQueue.addOperation(operation)
    }
}

// MARK: - Language
private extension TextInputView {
    func parse(with language: Language?) {
        let parser = Parser(encoding: .utf8)
        parser.delegate = self
        parser.reset()
        parser.language = language
        if language != nil {
            parser.parse(string as String)
        }
        syntaxHighlightController.parser = parser
        syntaxHighlightController.reset()
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
        if string.length == 0 {
            return CGRect(x: layoutManager.totalGutterWidth, y: 0, width: Caret.width, height: Caret.defaultHeight(for: theme.font))
        } else if let caretRect = layoutManager.caretRect(at: indexedPosition.index) {
            return caretRect
        } else {
            fatalError("Cannot create caret rect as line is unavailable.")
        }
    }

    func firstRect(for range: UITextRange) -> CGRect {
        guard let indexedRange = range as? IndexedRange else {
            fatalError("Expected range to be of type \(IndexedRange.self)")
        }
        if let firstRect = layoutManager.firstRect(for: indexedRange.range) {
            return firstRect
        } else {
            fatalError("First rect is unavailable.")
        }
    }
}

// MARK: - Editing
extension TextInputView {
    func insertText(_ text: String) {
        if let range = selectedRange, shouldChangeText(in: range, replacementText: text) {
            let nsString = text as NSString
            replaceCharacters(in: range, with: nsString)
            inputDelegate?.selectionWillChange(self)
            selectedRange = NSRange(location: range.location + nsString.length, length: 0)
            inputDelegate?.selectionDidChange(self)
        }
    }

    func deleteBackward() {
        guard let range = selectedRange else {
            return
        }
        if range.length > 0 {
            if shouldChangeText(in: range, replacementText: "") {
                replaceCharacters(in: range, with: "")
                inputDelegate?.selectionWillChange(self)
                selectedRange = NSRange(location: range.location, length: 0)
                inputDelegate?.selectionDidChange(self)
            }
        } else if range.location > 0 {
            if shouldChangeText(in: range, replacementText: "") {
                let deleteRange = NSRange(location: range.location - 1, length: 1)
                replaceCharacters(in: deleteRange, with: "")
                inputDelegate?.selectionWillChange(self)
                selectedRange = NSRange(location: range.location, length: 0)
                inputDelegate?.selectionDidChange(self)
            }
        }
    }

    func replace(_ range: UITextRange, withText text: String) {
        if let indexedRange = range as? IndexedRange, shouldChangeText(in: indexedRange.range, replacementText: text) {
            replace(indexedRange.range, withText: text)
        }
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

    func replace(_ range: NSRange, withText text: String) {
        let nsText = text as NSString
        replaceCharacters(in: range, with: nsText)
        inputDelegate?.selectionWillChange(self)
        selectedRange = NSRange(location: range.location + nsText.length, length: 0)
        inputDelegate?.selectionDidChange(self)
    }

    private func replaceCharacters(in range: NSRange, with newString: NSString) {
        inputDelegate?.textWillChange(self)
        let byteRange = self.byteRange(from: range)
        let swiftNewString = newString as String
        let bytesRemoved = byteRange.length
        let bytesAdded = swiftNewString.byteCount
        var editedLines: Set<DocumentLineNode> = []
        let oldEndLinePosition = lineManager.linePosition(at: range.location + range.length)!
        string.replaceCharacters(in: range, with: swiftNewString)
        lineManager.removeCharacters(in: range, editedLines: &editedLines)
        lineManager.insert(newString, at: range.location, editedLines: &editedLines)
        let startLinePosition = lineManager.linePosition(at: range.location)!
        let newEndLinePosition = lineManager.linePosition(at: range.location + newString.length)!
        let edit = InputEdit(
            startByte: byteRange.location,
            oldEndByte: byteRange.location + bytesRemoved,
            newEndByte: byteRange.location + bytesAdded,
            startPoint: SourcePoint(startLinePosition),
            oldEndPoint: SourcePoint(oldEndLinePosition),
            newEndPoint: SourcePoint(newEndLinePosition))
        let parser = syntaxHighlightController.parser
        let oldTree = parser?.latestTree
        parser?.apply(edit)
        parser?.parse()
        // Find lines changed by Tree-sitter and make sure we rehighlight them
        if let oldTree = oldTree, let newTree = parser?.latestTree {
            let changedRanges = oldTree.rangesChanged(comparingTo: newTree)
            let changedLines = lines(in: changedRanges)
            editedLines.formUnion(changedLines)
        }
        layoutManager.invalidate(editedLines)
        layoutManager.setNeedsLayout()
        setNeedsLayout()
        inputDelegate?.textDidChange(self)
        delegate?.textInputViewDidChange(self)
    }

    private func lines(in changedRanges: [SourceRange]) -> Set<DocumentLineNode> {
        var lines: Set<DocumentLineNode> = []
        for changedRange in changedRanges {
            for row in changedRange.startPoint.row ... changedRange.endPoint.row {
                let line = lineManager.line(atIndex: Int(row))
                lines.insert(line)
            }
        }
        return lines
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

    private func targetPositionForMovingFromLine(containingCharacterAt sourceIndex: Int, lineOffset: Int) -> Int {
        guard let currentLinePosition = lineManager.linePosition(at: sourceIndex) else {
            return sourceIndex
        }
        let targetLineNumber = min(max(currentLinePosition.lineNumber + lineOffset, 0), lineManager.lineCount - 1)
        let targetLine = lineManager.line(atIndex: targetLineNumber)
        let localLineIndex = min(currentLinePosition.column, targetLine.data.length)
        return targetLine.location + localLineIndex
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
    func lineManager(_ lineManager: LineManager, substringIn range: NSRange) -> String {
        return string.substring(with: range)
    }

    func lineManager(_ lineManager: LineManager, didInsert line: DocumentLineNode) {
        layoutManager.invalidateContentSize()
        layoutManager.updateGutterWidth()
        delegate?.textInputViewDidInvalidateContentSize(self)
    }

    func lineManager(_ lineManager: LineManager, didRemove line: DocumentLineNode) {
        layoutManager.invalidateContentSize()
        layoutManager.removeLine(withID: line.id)
        layoutManager.updateGutterWidth()
        delegate?.textInputViewDidInvalidateContentSize(self)
    }
}

// MARK: - ParserDelegate
extension TextInputView: ParserDelegate {
    func parser(_ parser: Parser, bytesAt byteIndex: ByteCount) -> [Int8]? {
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
    func layoutManager(_ layoutManager: LayoutManager, stringIn range: NSRange) -> String {
        return string.substring(with: range)
    }

    func layoutManagerDidInvalidateContentSize(_ layoutManager: LayoutManager) {
        delegate?.textInputViewDidInvalidateContentSize(self)
    }

    func lengthOfString(in layoutManager: LayoutManager) -> Int {
        return string.length
    }
}
