//
//  EditorBackingView.swift
//  
//
//  Created by Simon Støvring on 05/01/2021.
//

import UIKit

protocol EditorBackingViewDelegate: AnyObject {
    func editorBackingViewDidInvalidateContentSize(_ view: EditorBackingView)
}

final class EditorBackingView: UIView {
    weak var delegate: EditorBackingViewDelegate?
    var string: NSMutableString {
        get {
            return _string
        }
        set {
            if _string != newValue {
                _string = newValue
                lineManager.rebuild(from: newValue)
                isContentSizeInvalid = true
            }
        }
    }
    var textColor: UIColor = .black {
        didSet {
            if textColor != oldValue {
                setNeedsDisplay()
            }
        }
    }
    var selectedTextRange: NSRange?
    var markedTextRange: NSRange?
    var font: UIFont? = .systemFont(ofSize: 16) {
        didSet {
            if font != oldValue {
                lineManager.estimatedLineHeight = font?.lineHeight ?? 16
                setNeedsDisplay()
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
        if isContentSizeInvalid {
            updateContentSize()
            isContentSizeInvalid = false
        }
        return _contentSize
    }
    var theme: EditorTheme = DefaultEditorTheme() {
        didSet {
            syntaxHighlightController.theme = theme
            setNeedsDisplay()
        }
    }
    private(set) var lineManager = LineManager()

    private var _string = NSMutableString()
    private var textRenderers: [DocumentLineNodeID: EditorTextRenderer] = [:]
    private var visibleTextRendererIDs: Set<DocumentLineNodeID> = []
    private var isContentSizeInvalid = false
    private var _contentSize: CGSize = .zero
    private let syntaxHighlightController = SyntaxHighlightController()

    init() {
        super.init(frame: .zero)
        layer.isGeometryFlipped = true
        lineManager.delegate = self
        lineManager.estimatedLineHeight = font?.lineHeight ?? 16
        syntaxHighlightController.theme = theme
        NotificationCenter.default.addObserver(self, selector: #selector(didReceiveMemoryWarning(_:)), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        if let context = UIGraphicsGetCurrentContext() {
            drawLines(in: rect, of: context)
        }
        if isContentSizeInvalid {
            delegate?.editorBackingViewDidInvalidateContentSize(self)
        }
    }

    func setState(_ state: EditorState) {
        _string = NSMutableString(string: state.text)
        lineManager = state.lineManager
        lineManager.delegate = self
        syntaxHighlightController.parser = state.parser
        syntaxHighlightController.parser?.delegate = self
        isContentSizeInvalid = true
    }
}

// MARK: - Editing
extension EditorBackingView {
    func insertText(_ text: String) {
        if let range = selectedTextRange {
            replaceCharacters(in: range, with: text)
            selectedTextRange = NSRange(location: range.location + text.utf16.count, length: 0)
        }
    }

    func deleteBackward() {
        if let range = selectedTextRange {
            if range.length > 0 {
                replaceCharacters(in: range, with: "")
                selectedTextRange = NSRange(location: range.location, length: 0)
            } else {
                let deleteRange = NSRange(location: range.location - 1, length: 1)
                replaceCharacters(in: deleteRange, with: "")
                selectedTextRange = NSRange(location: range.location, length: 0)
            }
        }
    }

    func replace(_ range: NSRange, withText text: String) {
        replaceCharacters(in: range, with: text)
        selectedTextRange = NSRange(location: range.location + text.utf16.count, length: 0)
    }

    func text(in range: NSRange) -> String? {
        if range.location >= 0 && range.location + range.length <= string.length {
            return string.substring(with: range)
        } else {
            return nil
        }
    }

    private func replaceCharacters(in range: NSRange, with newString: String) {
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
    }
}

// MARK: - Text Rects
extension EditorBackingView {
    func caretRect(atIndex index: Int) -> CGRect {
        if string.length == 0 {
            return CGRect(x: 0, y: 0, width: EditorCaret.width, height: EditorCaret.defaultHeight(for: font))
        } else if let line = lineManager.line(containingCharacterAt: index) {
            let textRenderer = getTextRenderer(for: line)
            let localIndex = index - line.location
            let caretRect = textRenderer.caretRect(atIndex: localIndex)
            let screenRect = EditorScreenRect(caretRect, in: line)
            return screenRect.rect
        } else {
            fatalError("Cannot find caret rect.")
        }
    }

    func firstRect(for range: NSRange) -> CGRect {
        if let line = lineManager.line(containingCharacterAt: range.location) {
            let textRenderer = getTextRenderer(for: line)
            let localRange = NSRange(location: range.location - line.location, length: min(range.length, line.value))
            let textRendererRect = textRenderer.firstRect(for: localRange)
            let screenRect = EditorScreenRect(textRendererRect, in: line)
            return screenRect.rect
        } else {
            fatalError("Cannot find first rect.")
        }
    }
}

// MARK: - Text Indices
extension EditorBackingView {
    func closestIndex(to point: CGPoint) -> Int? {
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
        let screenPoint = EditorScreenPoint(point)
        let rendererPoint = EditorTextRendererPoint(screenPoint, viewport: viewport, destinationRenderer: textRenderer)
        if let index = textRenderer.closestIndex(to: rendererPoint) {
            if index >= line.data.length && index <= line.data.totalLength && line != lineManager.lastLine {
                return line.location + line.data.length
            } else {
                return line.location + index
            }
        } else {
            return nil
        }
    }
}

// MARK: - Selection
extension EditorBackingView {
    func selectionRects(in range: NSRange) -> [EditorTextSelectionRect] {
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
                    var screenRect = EditorScreenRect(rendererSelectionRect.rect, in: line)
                    let startLocation = lineStartLocation + rendererSelectionRect.range.location
                    let endLocation = startLocation + rendererSelectionRect.range.length
                    let containsStart = range.location >= startLocation && range.location <= endLocation
                    let containsEnd = range.location + range.length >= startLocation && range.location + range.length <= endLocation
                    if endLocation < range.location + range.length {
                        screenRect.size.width = viewport.size.width - screenRect.minX
                    }
                    return EditorTextSelectionRect(rect: screenRect.rect, writingDirection: .leftToRight, containsStart: containsStart, containsEnd: containsEnd)
                }
                selectionRects.append(contentsOf: textSelectionRects)
            }
        }
        return selectionRects.ensuringYAxisAlignemnt()
    }
}

// MARK: - Drawing
private extension EditorBackingView {
    private func drawLines(in rect: CGRect, of context: CGContext) {
        visibleTextRendererIDs = []
        let visibleLines = lineManager.visibleLines(in: viewport)
        for visibleLine in visibleLines {
            draw(visibleLine, in: rect, of: context)
            visibleTextRendererIDs.insert(visibleLine.id)
        }
    }

    private func draw(_ line: DocumentLineNode, in rect: CGRect, of context: CGContext) {
        let lineLocation = line.location
        let textRenderer = getTextRenderer(for: line)
        let range = NSRange(location: lineLocation, length: line.value)
        let lineString = string.substring(with: range) as NSString
        let attributes = syntaxHighlightController.attributes(in: range, lineStartLocation: lineLocation)
        textRenderer.setString(lineString, attributes: attributes)
        textRenderer.textColor = textColor
        textRenderer.constrainingWidth = bounds.width
        let size = textRenderer.preferredSize
        let screenRect = EditorScreenRect(x: 0, y: line.yPosition, width: bounds.width, height: size.height)
        let drawableRect = EditorTextDrawableRect(screenRect, viewport: viewport)
        let didUpdateHeight = lineManager.setHeight(size.height, of: line)
        textRenderer.origin = drawableRect.origin
        textRenderer.draw(in: context)
        if didUpdateHeight {
            isContentSizeInvalid = true
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
        textRenderer.origin = CGPoint(x: 0, y: line.yPosition)
        textRenderers[line.id] = textRenderer
        return textRenderer
    }

    private func updateContentSize() {
        _contentSize = CGSize(width: bounds.width, height: lineManager.contentHeight)
    }
}

// MARK: - Memory Management
private extension EditorBackingView {
    @objc private func didReceiveMemoryWarning(_ notification: Notification) {
        let allTextRendererIDs = Set(textRenderers.keys)
        let unusedTextRendererIDs = allTextRendererIDs.subtracting(visibleTextRendererIDs)
        for unusedTextRendererID in unusedTextRendererIDs {
            textRenderers.removeValue(forKey: unusedTextRendererID)
        }
    }
}

// MARK: - LineManagerDelegate
extension EditorBackingView: LineManagerDelegate {
    func lineManager(_ lineManager: LineManager, characterAtLocation location: Int) -> String {
        return string.substring(with: NSMakeRange(location, 1))
    }

    func lineManager(_ lineManager: LineManager, didInsert line: DocumentLineNode) {
        isContentSizeInvalid = true
        createTextRenderer(for: line)
    }

    func lineManager(_ lineManager: LineManager, didRemove line: DocumentLineNode) {
        isContentSizeInvalid = true
        textRenderers.removeValue(forKey: line.id)
    }
}

// MARK: - ParserDelegate
extension EditorBackingView: ParserDelegate {
    func parser(_ parser: Parser, substringAtByteIndex byteIndex: uint, point: SourcePoint) -> String? {
        if byteIndex < string.length {
            return string.substring(with: NSRange(location: Int(byteIndex), length: 1))
        } else {
            return nil
        }
    }
}

private extension LinePosition {
    func offsettingLineNumber(by offset: Int) -> LinePosition {
        return LinePosition(lineStartLocation: lineStartLocation, lineNumber: lineNumber + offset, column: column, totalLength: totalLength)
    }
}
