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
    func editorTextInputViewDidInvalidateContentSize(_ view: EditorTextInputView)
}

final class EditorTextInputView: UIView, UITextInput {
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
            let newRange = (newValue as? EditorIndexedRange)?.range
            if newRange != selectedRange {
                inputDelegate?.selectionWillChange(self)
                selectedRange = newRange
                inputDelegate?.selectionDidChange(self)
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
                setNeedsDisplay()
            }
        }
    }
    var font: UIFont? = .systemFont(ofSize: 16) {
        didSet {
            if font != oldValue {
                lineManager.estimatedLineHeight = font?.lineHeight ?? 16
                setNeedsDisplay()
            }
        }
    }
    var theme: EditorTheme = DefaultEditorTheme() {
        didSet {
            syntaxHighlightController.theme = theme
            setNeedsDisplay()
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
                setNeedsDisplay()
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
                setNeedsDisplay()
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
    private var textRenderers: [DocumentLineNodeID: EditorTextRenderer] = [:]
    private var visibleTextRendererIDs: Set<DocumentLineNodeID> = []
    private var _contentSize: CGSize?
    private let syntaxHighlightController = SyntaxHighlightController()
    private let tapGestureRecognizer = UITapGestureRecognizer()

    // MARK: - Lifecycle
    init() {
        super.init(frame: .zero)
        lineManager.delegate = self
        lineManager.estimatedLineHeight = font?.lineHeight ?? 16
        syntaxHighlightController.theme = theme
        tapGestureRecognizer.delegate = self
        tapGestureRecognizer.addTarget(self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGestureRecognizer)
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
            markedTextRange = nil
            if selectedTextRange == nil {
                selectedRange = NSRange(location: 0, length: 0)
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
            selectedTextRange = nil
            markedTextRange = nil
            tapGestureRecognizer.isEnabled = true
        }
        return didResignFirstResponder
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
}

// MARK: - Interaction
private extension EditorTextInputView {
    @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        if tapGestureRecognizer.state == .ended {
            let point = gestureRecognizer.location(in: self)
            if let index = closestIndex(to: point) {
                selectedRange = NSRange(location: index, length: 0)
            }
            becomeFirstResponder()
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
            let textRenderer = getTextRenderer(for: line)
            let localIndex = indexedPosition.index - line.location
            let caretRect = textRenderer.caretRect(atIndex: localIndex)
            return CGRect(x: caretRect.minX, y: line.yPosition + caretRect.minY, width: caretRect.width, height: caretRect.height)
        } else {
            fatalError("Cannot find caret rect.")
        }
    }

    func firstRect(for range: UITextRange) -> CGRect {
        guard let indexedRange = range as? EditorIndexedRange else {
            fatalError("Expected range to be of type \(EditorIndexedRange.self)")
        }
        let range = indexedRange.range
        if let line = lineManager.line(containingCharacterAt: range.location) {
            let textRenderer = getTextRenderer(for: line)
            let localRange = NSRange(location: range.location - line.location, length: min(range.length, line.value))
            var rect = textRenderer.firstRect(for: localRange)
            rect.origin.y += line.yPosition
            return rect
        } else {
            fatalError("Cannot find first rect.")
        }
    }
}

// MARK: - Editing
extension EditorTextInputView {
    func insertText(_ text: String) {
        if let range = selectedRange {
            replaceCharacters(in: range, with: text)
            selectedRange = NSRange(location: range.location + text.utf16.count, length: 0)
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
            replace(indexedRange.range, withText: text)
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

    private func replace(_ range: NSRange, withText text: String) {
        replaceCharacters(in: range, with: text)
        selectedRange = NSRange(location: range.location + text.utf16.count, length: 0)
    }

    private func replaceCharacters(in range: NSRange, with newString: String) {
        inputDelegate?.textWillChange(self)
        var editedLines: Set<DocumentLineNode> = []
        let nsString = newString as NSString
        let bytesRemoved = range.length
        let bytesAdded = nsString.length
        let oldEndLinePosition = lineManager.linePosition(at: range.location + bytesRemoved)
        string.replaceCharacters(in: range, with: newString)
        lineManager.removeCharacters(in: range, editedLines: &editedLines)
        lineManager.insert(nsString, at: range.location, editedLines: &editedLines)
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
            syntaxHighlightController.parser?.apply(edit)
            syntaxHighlightController.parser?.parse()
        } else {
            fatalError("Cannot edit syntax tree because one or more line positions are not available")
        }
        updateStrings(on: editedLines)
        setNeedsDisplay()
        inputDelegate?.textDidChange(self)
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
            if let textRenderer = textRenderers[line.id] {
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
        }
        return selectionRects.ensuringYAxisAlignemnt()
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
        case .right:
            newPosition += offset
        case .left:
            newPosition -= offset
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
        if let line = lineManager.line(containingYOffset: point.y) {
            let textRenderer = getTextRenderer(for: line)
            return closestIndex(to: point, in: textRenderer, showing: line)
        } else if point.y <= 0 {
            let firstLine = lineManager.firstLine
            let textRenderer = getTextRenderer(for: firstLine)
            return closestIndex(to: point, in: textRenderer, showing: firstLine)
        } else {
            let lastLine = lineManager.lastLine
            if point.y >= lastLine.yPosition {
                let textRenderer = getTextRenderer(for: lastLine)
                return closestIndex(to: point, in: textRenderer, showing: lastLine)
            } else {
                fatalError("Cannot find first rect.")
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
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        if let context = UIGraphicsGetCurrentContext() {
            context.saveGState()
            context.textMatrix = .identity
            context.scaleBy(x: 1, y: -1)
            drawLines(in: viewport, of: context)
            context.restoreGState()
        }
        if _contentSize == nil {
            delegate?.editorTextInputViewDidInvalidateContentSize(self)
        }
    }

    private func drawLines(in rect: CGRect, of context: CGContext) {
        visibleTextRendererIDs = []
        let visibleLines = lineManager.visibleLines(in: rect)
        for visibleLine in visibleLines {
            draw(visibleLine, in: context)
            visibleTextRendererIDs.insert(visibleLine.id)
        }
    }

    private func draw(_ line: DocumentLineNode, in context: CGContext) {
        let lineLocation = line.location
        let textRenderer = getTextRenderer(for: line)
        let range = NSRange(location: lineLocation, length: line.value)
        let lineString = string.substring(with: range) as NSString
        let attributes = syntaxHighlightController.attributes(in: range, lineStartLocation: lineLocation)
        textRenderer.setString(lineString, attributes: attributes)
        textRenderer.textColor = textColor
        textRenderer.constrainingWidth = frame.width
        let size = textRenderer.preferredSize
        let didUpdateHeight = lineManager.setHeight(size.height, of: line)
        context.saveGState()
        context.translateBy(x: 0, y: (size.height + line.yPosition) * -1)
        textRenderer.draw(in: context)
        context.restoreGState()
        if didUpdateHeight {
            _contentSize = nil
        }
        if textRenderers[line.id] == nil {
            textRenderers[line.id] = textRenderer
        }
    }

    private func updateStrings(on lines: Set<DocumentLineNode>) {
        for line in lines {
            if let textRenderer = textRenderers[line.id] {
                let range = NSRange(location: line.location, length: line.value)
                let substring = string.substring(with: range) as NSString
                textRenderer.setString(substring, attributes: [])
                let size = textRenderer.preferredSize
                lineManager.setHeight(size.height, of: line)
            }
        }
    }

    private func getTextRenderer(for line: DocumentLineNode) -> EditorTextRenderer {
        if let textRenderer = textRenderers[line.id] {
            return textRenderer
        } else {
            return createTextRenderer(for: line)
        }
    }

    @discardableResult
    private func createTextRenderer(for line: DocumentLineNode) -> EditorTextRenderer {
        let textRenderer = EditorTextRenderer()
        textRenderer.font = font
        textRenderers[line.id] = textRenderer
        return textRenderer
    }
}

// MARK: - Memory Management
private extension EditorTextInputView {
    @objc private func didReceiveMemoryWarning(_ notification: Notification) {
        let allTextRendererIDs = Set(textRenderers.keys)
        let unusedTextRendererIDs = allTextRendererIDs.subtracting(visibleTextRendererIDs)
        for unusedTextRendererID in unusedTextRendererIDs {
            textRenderers.removeValue(forKey: unusedTextRendererID)
        }
    }
}

// MARK: - LineManagerDelegate
extension EditorTextInputView: LineManagerDelegate {
    func lineManager(_ lineManager: LineManager, characterAtLocation location: Int) -> String {
        return string.substring(with: NSMakeRange(location, 1))
    }

    func lineManager(_ lineManager: LineManager, didInsert line: DocumentLineNode) {
        _contentSize = nil
        createTextRenderer(for: line)
    }

    func lineManager(_ lineManager: LineManager, didRemove line: DocumentLineNode) {
        _contentSize = nil
        textRenderers.removeValue(forKey: line.id)
    }
}

// MARK: - ParserDelegate
extension EditorTextInputView: ParserDelegate {
    func parser(_ parser: Parser, substringAtByteIndex byteIndex: uint, point: SourcePoint) -> String? {
        if byteIndex < string.length {
            return string.substring(with: NSRange(location: Int(byteIndex), length: 1))
        } else {
            return nil
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension EditorTextInputView: UIGestureRecognizerDelegate {
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === tapGestureRecognizer {
            return !isFirstResponder
        } else {
            return true
        }
    }
}

// MARK: - Helpers
private extension LinePosition {
    func offsettingLineNumber(by offset: Int) -> LinePosition {
        return LinePosition(lineStartLocation: lineStartLocation, lineNumber: lineNumber + offset, column: column, totalLength: totalLength)
    }
}
