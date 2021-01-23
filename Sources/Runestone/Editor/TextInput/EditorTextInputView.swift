//
//  EditorTextInputView.swift
//  
//
//  Created by Simon Støvring on 05/01/2021.
//

import UIKit

protocol EditorTextInputViewDelegate: AnyObject {
    func editorTextInputViewDidBeginEditing(_ view: EditorTextInputView)
    func editorTextInputViewDidEndEditing(_ view: EditorTextInputView)
    func editorTextInputViewDidChange(_ view: EditorTextInputView)
    func editorTextInputViewDidInvalidateContentSize(_ view: EditorTextInputView)
}

final class EditorTextInputView: UIView, UITextInput {
    private struct CaretRect {
        let position: EditorIndexedPosition
        let rect: CGRect
    }

    // MARK: - UITextInput
    var selectedTextRange: UITextRange? {
        get {
            if let range = selectedRange {
                return EditorIndexedRange(range: range)
            } else {
                return nil
            }
        }
        set {
            if let newRange = (newValue as? EditorIndexedRange)?.range {
                if newRange != selectedRange {
                    inputDelegate?.selectionWillChange(self)
                    selectedRange = newRange
                    inputDelegate?.selectionDidChange(self)
                }
            } else {
                selectedRange = nil
            }
        }
    }
    private(set) var markedTextRange: UITextRange?
    var markedTextStyle: [NSAttributedString.Key: Any]?
    var beginningOfDocument: UITextPosition {
        return EditorIndexedPosition(index: 0)
    }
    var endOfDocument: UITextPosition {
        return EditorIndexedPosition(index: string.length)
    }
    var inputDelegate: UITextInputDelegate?
    var hasText: Bool {
        return string.length > 0
    }
    private(set) lazy var tokenizer: UITextInputTokenizer = EditorTextInputStringTokenizer(textInput: self, lineManager: lineManager)
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

    // MARK: - Styling
    var textColor: UIColor = .black {
        didSet {
            if textColor != oldValue {
//                setNeedsDisplay()
            }
        }
    }
    var font: UIFont? = .systemFont(ofSize: 16) {
        didSet {
            if font != oldValue {
                lineManager.estimatedLineHeight = font?.lineHeight ?? 16
//                setNeedsDisplay()
            }
        }
    }
    var theme: EditorTheme = DefaultEditorTheme() {
        didSet {
            syntaxHighlightController.theme = theme
//            setNeedsDisplay()
        }
    }

    // MARK: - Contents
    var string: NSMutableString {
        get {
            return _string
        }
        set {
            if _string != newValue {
                _string = newValue
                lineManager.rebuild(from: newValue)
                _contentSize = nil
            }
        }
    }
    var viewport: CGRect = .zero {
        didSet {
            if viewport != oldValue {
                inputDelegate?.selectionWillChange(self)
                layoutLines()
                inputDelegate?.selectionDidChange(self)
            }
        }
    }
    var contentSize: CGSize {
        if let contentSize = _contentSize {
            return contentSize
        } else {
            let contentSize = CGSize(width: frame.width, height: lineManager.contentHeight)
            _contentSize = contentSize
            return contentSize
        }
    }

    // MARK: - Misc
    weak var delegate: EditorTextInputViewDelegate?
    override var frame: CGRect {
        didSet {
            if frame.size != oldValue.size {
//                setNeedsDisplay()
//                layoutLines()
            }
        }
    }
    override var canBecomeFirstResponder: Bool {
        return true
    }

    // MARK: - Private
    private var _string = NSMutableString()
    private var selectedRange: NSRange?
    private var markedRange: NSRange?
    private var lineManager = LineManager()
    private var _contentSize: CGSize?
    private let syntaxHighlightController = SyntaxHighlightController()
    private var queuedLineViews: Set<EditorLineView> = []
    private var visibleLineViews: [DocumentLineNodeID: EditorLineView] = [:]
    private var textRenderers: [DocumentLineNodeID: EditorTextRenderer] = [:]
    private let syntaxHighlightQueue = OperationQueue()

    // MARK: - Lifecycle
    init() {
        super.init(frame: .zero)
        lineManager.delegate = self
        lineManager.estimatedLineHeight = font?.lineHeight ?? 16
        syntaxHighlightController.theme = theme
        syntaxHighlightQueue.name = "Runestone.SyntaxHighlightQueue"
        syntaxHighlightQueue.qualityOfService = .userInitiated
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveMemoryWarning(_:)), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @discardableResult
    public override func becomeFirstResponder() -> Bool {
        let wasFirstResponder = isFirstResponder
        let didBecomeFirstResponder = super.becomeFirstResponder()
        if !wasFirstResponder && isFirstResponder {
            markedRange = nil
            if selectedRange == nil {
                inputDelegate?.selectionWillChange(self)
                selectedRange = NSRange(location: 0, length: 0)
                inputDelegate?.selectionDidChange(self)
            }
            delegate?.editorTextInputViewDidBeginEditing(self)
        }
        return didBecomeFirstResponder
    }

    @discardableResult
    public override func resignFirstResponder() -> Bool {
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
}

// MARK: - Public
extension EditorTextInputView {
    func setState(_ state: EditorState) {
        _string = NSMutableString(string: state.text)
        lineManager = state.lineManager
        lineManager.delegate = self
        syntaxHighlightController.parser = state.parser
        syntaxHighlightController.parser?.delegate = self
        _contentSize = nil
    }

    func moveCaret(to point: CGPoint) {
        if let index = closestIndex(to: point) {
            selectedRange = NSRange(location: index, length: 0)
        }
    }
}

// MARK: - Rects
extension EditorTextInputView {
    func caretRect(for position: UITextPosition) -> CGRect {
        guard let indexedPosition = position as? EditorIndexedPosition else {
            fatalError("Expected position to be of type \(EditorIndexedPosition.self)")
        }
        if string.length == 0 {
            return CGRect(x: 0, y: 0, width: EditorCaret.width, height: EditorCaret.defaultHeight(for: font))
        } else if let line = lineManager.line(containingCharacterAt: indexedPosition.index) {
            let textRenderer = textRenderers[line.id]!
            let localIndex = indexedPosition.index - line.location
            let localCaretRect = textRenderer.caretRect(atIndex: localIndex)
            let globalYPosition = line.yPosition + localCaretRect.minY
            return CGRect(x: localCaretRect.minX, y: globalYPosition, width: localCaretRect.width, height: localCaretRect.height)
        } else {
            fatalError("Cannot create caret rect as line is unavailable.")
        }
    }

    func firstRect(for range: UITextRange) -> CGRect {
        guard let indexedRange = range as? EditorIndexedRange else {
            fatalError("Expected range to be of type \(EditorIndexedRange.self)")
        }
        let range = indexedRange.range
        guard let line = lineManager.line(containingCharacterAt: range.location) else {
            fatalError("Cannot find first rect.")
        }
        let textRenderer = textRenderers[line.id]!
        let localRange = NSRange(location: range.location - line.location, length: min(range.length, line.value))
        if let firstRect = textRenderer.firstRect(for: localRange) {
            return firstRect
        } else {
            fatalError("First rect is unavailable.")
        }
    }
}

// MARK: - Editing
extension EditorTextInputView {
    func insertText(_ text: String) {
        if let range = selectedRange {
            let nsString = text as NSString
            replaceCharacters(in: range, with: nsString)
            selectedRange = NSRange(location: range.location + nsString.length, length: 0)
        }
    }

    func deleteBackward() {
        guard let range = selectedRange else {
            return
        }
        if range.length > 0 {
            replaceCharacters(in: range, with: "")
            selectedRange = NSRange(location: range.location, length: 0)
        } else {
            let deleteRange = NSRange(location: range.location - 1, length: 1)
            replaceCharacters(in: deleteRange, with: "")
            selectedRange = NSRange(location: range.location, length: 0)
        }
    }

    func replace(_ range: UITextRange, withText text: String) {
        if let indexedRange = range as? EditorIndexedRange {
            replace(indexedRange.range, withText: text as NSString)
        }
    }

    func text(in range: UITextRange) -> String? {
        if let indexedRange = range as? EditorIndexedRange {
            return text(in: indexedRange.range)
        } else {
            return nil
        }
    }

    private func text(in range: NSRange) -> String? {
        if range.location >= 0 && range.location + range.length <= string.length {
            return string.substring(with: range)
        } else {
            return nil
        }
    }

    private func replace(_ range: NSRange, withText text: NSString) {
        replaceCharacters(in: range, with: text)
        selectedRange = NSRange(location: range.location + text.length, length: 0)
    }

    private func replaceCharacters(in range: NSRange, with newString: NSString) {
        inputDelegate?.textWillChange(self)
        let swiftString = string as String
        let swiftNewString = newString as String
        let byteRange = swiftString.byteRange(from: range)
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
        updateLineViews(showing: editedLines, for: swiftString)
        layoutLines()
        inputDelegate?.textDidChange(self)
        delegate?.editorTextInputViewDidChange(self)
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
}

// MARK: - Selection
extension EditorTextInputView {
    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        if let indexedRange = range as? EditorIndexedRange {
            return selectionRects(in: indexedRange.range)
        } else {
            return []
        }
    }

    private func selectionRects(in range: NSRange) -> [EditorTextSelectionRect] {
        guard let startLine = lineManager.line(containingCharacterAt: range.location) else {
            return []
        }
        guard let endLine = lineManager.line(containingCharacterAt: range.location + range.length) else {
            return []
        }
        var selectionRects: [EditorTextSelectionRect] = []
        let lineIndexRange = startLine.index ..< endLine.index + 1
        for lineIndex in lineIndexRange {
            let line = lineManager.line(atIndex: lineIndex)
            let textRenderer = getTextRenderer(for: line)
            let lineStartLocation = line.location
            let lineEndLocation = lineStartLocation + line.data.totalLength
            let localRangeLocation = max(range.location, lineStartLocation) - lineStartLocation
            let localRangeLength = min(range.location + range.length, lineEndLocation) - lineStartLocation - localRangeLocation
            let localRange = NSRange(location: localRangeLocation, length: localRangeLength)
            let rendererSelectionRects = textRenderer.selectionRects(in: localRange)
            let textSelectionRects: [EditorTextSelectionRect] = rendererSelectionRects.map { rendererSelectionRect in
                let y = line.yPosition + rendererSelectionRect.rect.minY
                var screenRect = CGRect(x: rendererSelectionRect.rect.minX, y: y, width: rendererSelectionRect.rect.width, height: rendererSelectionRect.rect.height)
                let startLocation = lineStartLocation + rendererSelectionRect.range.location
                let endLocation = startLocation + rendererSelectionRect.range.length
                let containsStart = range.location >= startLocation && range.location <= endLocation
                let containsEnd = range.location + range.length >= startLocation && range.location + range.length <= endLocation
                if endLocation < range.location + range.length {
                    screenRect.size.width = frame.width - screenRect.minX
                }
                return EditorTextSelectionRect(rect: screenRect, writingDirection: .leftToRight, containsStart: containsStart, containsEnd: containsEnd)
                }
            selectionRects.append(contentsOf: textSelectionRects)
        }
        return selectionRects.ensuringYAxisAlignment()
    }
}

// MARK: - Marking
extension EditorTextInputView {
    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {}

    func unmarkText() {}
}

// MARK: - Ranges and Positions
extension EditorTextInputView {
    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        return nil
    }

    func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        guard let indexedPosition = position as? EditorIndexedPosition else {
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
            return EditorIndexedPosition(index: newPosition)
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
        if let index = closestIndex(to: point) {
            return EditorIndexedPosition(index: index)
        } else {
            return nil
        }
    }

    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        return nil
    }

    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        guard let fromIndexedPosition = fromPosition as? EditorIndexedPosition, let toIndexedPosition = toPosition as? EditorIndexedPosition else {
            return nil
        }
        let range = NSRange(location: fromIndexedPosition.index, length: toIndexedPosition.index - fromIndexedPosition.index)
        return EditorIndexedRange(range: range)
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        guard let indexedPosition = position as? EditorIndexedPosition else {
            return nil
        }
        let newPosition = indexedPosition.index + offset
        guard newPosition >= 0 && newPosition <= string.length else {
            return nil
        }
        return EditorIndexedPosition(index: newPosition)
    }

    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        guard let indexedPosition = position as? EditorIndexedPosition, let otherIndexedPosition = other as? EditorIndexedPosition else {
            fatalError("Positions must be of type \(EditorIndexedPosition.self)")
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
        if let fromPosition = from as? EditorIndexedPosition, let toPosition = toPosition as? EditorIndexedPosition {
            return toPosition.index - fromPosition.index
        } else {
            return 0
        }
    }

    private func closestIndex(to point: CGPoint) -> Int? {
        if let line = lineManager.line(containingYOffset: point.y), let textRenderer = textRenderers[line.id] {
            return closestIndex(to: point, in: textRenderer, showing: line)
        } else if point.y <= 0 {
            let firstLine = lineManager.firstLine
            if let textRenderer = textRenderers[firstLine.id] {
                return closestIndex(to: point, in: textRenderer, showing: firstLine)
            } else {
                return 0
            }
        } else {
            let lastLine = lineManager.lastLine
            if point.y >= lastLine.yPosition, let textRenderer = textRenderers[lastLine.id] {
                return closestIndex(to: point, in: textRenderer, showing: lastLine)
            } else {
                return string.length
            }
        }
    }

    private func closestIndex(to point: CGPoint, in textRenderer: EditorTextRenderer, showing line: DocumentLineNode) -> Int? {
        if let index = textRenderer.closestIndex(to: point) {
            if index >= line.data.length && index <= line.data.totalLength && line != lineManager.lastLine {
                return line.location + line.data.length
            } else {
                return line.location + index
            }
        } else {
            return nil
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
extension EditorTextInputView {
    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection {
        return .natural
    }

    func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {}
}

// MARK: - Drawing
extension EditorTextInputView {
    private func layoutLines() {
        let currentVisibleLineIDs = Set(visibleLineViews.keys)
        let newVisibleLines = lineManager.visibleLines(in: viewport)
        let newVisibleLineIDs = Set(newVisibleLines.map(\.id))
        let lineIDsToEnqueue = currentVisibleLineIDs.subtracting(newVisibleLineIDs)
        enqueueLineViews(withIDs: lineIDsToEnqueue)
        let swiftString = string as String
        for visibleLine in newVisibleLines {
            show(visibleLine, for: swiftString)
        }
        if _contentSize == nil {
            delegate?.editorTextInputViewDidInvalidateContentSize(self)
        }
    }

    private func show(_ line: DocumentLineNode, for swiftString: String) {
        syntaxHighlightController.prepare()
        let lineView = dequeueLineView(withID: line.id)
        if lineView.superview == nil {
            addSubview(lineView)
        }
        let textRenderer = getTextRenderer(for: line)
        prepare(textRenderer, toShow: line)
        lineView.textRenderer = textRenderer
        lineView.frame = CGRect(x: 0, y: line.yPosition, width: frame.width, height: textRenderer.totalHeight)
        lineView.backgroundColor = backgroundColor
        let range = NSRange(location: line.location, length: line.value)
        let byteRange = swiftString.byteRange(from: range)
        textRenderer.syntaxHighlight(byteRange, inLineWithID: line.id)
    }

    private func enqueueLineViews(withIDs lineIDs: Set<DocumentLineNodeID>) {
        for lineID in lineIDs {
            if let lineView = visibleLineViews.removeValue(forKey: lineID) {
                lineView.removeFromSuperview()
                queuedLineViews.insert(lineView)
            }
        }
    }

    private func dequeueLineView(withID lineID: DocumentLineNodeID) -> EditorLineView {
        if let lineView = visibleLineViews[lineID] {
            return lineView
        } else if !queuedLineViews.isEmpty {
            let lineView = queuedLineViews.removeFirst()
            visibleLineViews[lineID] = lineView
            return lineView
        } else {
            let lineView = EditorLineView()
            visibleLineViews[lineID] = lineView
            return lineView
        }
    }

    private func getTextRenderer(for line: DocumentLineNode) -> EditorTextRenderer {
        if let cachedTextRenderer = textRenderers[line.id] {
            return cachedTextRenderer
        } else {
            let textRenderer = EditorTextRenderer(syntaxHighlightController: syntaxHighlightController, syntaxHighlightQueue: syntaxHighlightQueue)
            textRenderer.delegate = self
            prepare(textRenderer, toShow: line)
            textRenderers[line.id] = textRenderer
            return textRenderer
        }
    }

    private func prepare(_ textRenderer: EditorTextRenderer, toShow line: DocumentLineNode) {
        textRenderer.line = line
        textRenderer.lineWidth = frame.width
        textRenderer.font = font
        textRenderer.textColor = textColor
        textRenderer.prepare()
        let lineHeight = ceil(textRenderer.totalHeight)
        let didUpdateHeight = lineManager.setHeight(of: line, to: lineHeight)
        if didUpdateHeight {
            _contentSize = nil
        }
    }

    private func updateLineViews(showing lines: Set<DocumentLineNode>, for swiftString: String) {
        for line in lines {
            if let textRenderer = textRenderers[line.id] {
                syntaxHighlightController.removedCachedAttributes(for: line.id)
                textRenderer.invalidate()
//                let lineLocation = line.location
//                let range = NSRange(location: lineLocation, length: line.value)
//                let lineString = string.substring(with: range)
//                let byteRange = swiftString.byteRange(from: range)
//                textRenderer.show(lineString, fromLineWithID: line.id)
//                textRenderer.syntaxHighlight(byteRange, inLineWithID: line.id)
//                lineManager.setHeight(textRenderer.totalHeight, of: line)
            }
        }
    }
}

// MARK: - Memory Management
private extension EditorTextInputView {
    @objc private func didReceiveMemoryWarning(_ notification: Notification) {
        syntaxHighlightController.clearCache()
    }
}

// MARK: - LineManagerDelegate
extension EditorTextInputView: LineManagerDelegate {
    func lineManager(_ lineManager: LineManager, characterAtLocation location: Int) -> String {
        return string.substring(with: NSMakeRange(location, 1))
    }

    func lineManager(_ lineManager: LineManager, didInsert line: DocumentLineNode) {
        _contentSize = nil
    }

    func lineManager(_ lineManager: LineManager, didRemove line: DocumentLineNode) {
        _contentSize = nil
        textRenderers.removeValue(forKey: line.id)
    }
}

// MARK: - ParserDelegate
extension EditorTextInputView: ParserDelegate {
    func parser(_ parser: Parser, bytesAt byteIndex: ByteCount) -> [Int8]? {
        let swiftString = string as String
        let location = swiftString.location(from: byteIndex)
        guard location < string.length else {
            return nil
        }
        let range = string.rangeOfComposedCharacterSequence(at: location)
        let substring = string.substring(with: range)
        return substring.cString(using: .utf8)?.dropLast()
    }
}

// MARK: - EditorTextRendererDelegate
extension EditorTextInputView: EditorTextRendererDelegate {
    func editorTextRenderer(_ textRenderer: EditorTextRenderer, stringIn line: DocumentLineNode) -> String {
        let range = NSRange(location: line.location, length: line.value)
        return string.substring(with: range)
    }

    func editorTextRendererDidUpdateSyntaxHighlighting(_ textRenderer: EditorTextRenderer) {
        if let lineID = textRenderer.line?.id {
            let lineView = visibleLineViews[lineID]
            lineView?.setNeedsDisplay()
        }
    }
}
