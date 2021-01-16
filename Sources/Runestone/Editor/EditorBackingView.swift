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
    var selectedTextRange: NSRange?
    var markedTextRange: NSRange?
    var font = UIFont(name: "Menlo-Regular", size: 14)! {
        didSet {
            if font != oldValue {
                lineManager.estimatedLineHeight = font.lineHeight
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
    private(set) var lineManager = LineManager()
    private(set) var parser: Parser?
    private(set) var _string = NSMutableString()

    private var textRenderers: [DocumentLineNodeID: EditorTextRenderer] = [:]
    private var visibleTextRendererIDs: Set<DocumentLineNodeID> = []
    private var isContentSizeInvalid = false
    private var _contentSize: CGSize = .zero

    init() {
        super.init(frame: .zero)
        layer.isGeometryFlipped = true
        lineManager.delegate = self
        lineManager.estimatedLineHeight = font.lineHeight
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
        parser = state.parser
        isContentSizeInvalid = true
    }
}

// MARK: - Editing
extension EditorBackingView {
    func insertText(_ text: String) {
        guard let selectedTextRange = selectedTextRange else {
            return
        }
        if selectedTextRange.length > 0 {
            // Replace selected text.
            var editedLines: Set<DocumentLineNode> = []
            string.replaceCharacters(in: selectedTextRange, with: text)
            lineManager.removeCharacters(in: selectedTextRange, editedLines: &editedLines)
            lineManager.insert(text as NSString, at: selectedTextRange.location, editedLines: &editedLines)
            self.selectedTextRange = NSRange(location: selectedTextRange.location + text.utf16.count, length: 0)
            updateStrings(on: editedLines)
            setNeedsDisplay()
        } else {
            // Insert text at location.
            var editedLines: Set<DocumentLineNode> = []
            string.insert(text, at: selectedTextRange.location)
            lineManager.insert(text as NSString, at: selectedTextRange.location, editedLines: &editedLines)
            self.selectedTextRange = NSRange(location: selectedTextRange.location + text.utf16.count, length: 0)
            updateStrings(on: editedLines)
            setNeedsDisplay()
        }
    }

    func deleteBackward() {
        guard let selectedTextRange = selectedTextRange else {
            return
        }
        if selectedTextRange.length > 0 {
            // Delete selected text.
            var editedLines: Set<DocumentLineNode> = []
            string.deleteCharacters(in: selectedTextRange)
            lineManager.removeCharacters(in: selectedTextRange, editedLines: &editedLines)
            self.selectedTextRange = NSRange(location: selectedTextRange.location, length: 0)
            updateStrings(on: editedLines)
            setNeedsDisplay()
        } else if selectedTextRange.location > 0 {
            // Delete a single character at the location.
            var editedLines: Set<DocumentLineNode> = []
            let range = NSRange(location: selectedTextRange.location - 1, length: 1)
            string.deleteCharacters(in: range)
            lineManager.removeCharacters(in: range, editedLines: &editedLines)
            self.selectedTextRange = NSRange(location: range.location, length: 0)
            updateStrings(on: editedLines)
            setNeedsDisplay()
        }
    }

    func replace(_ range: NSRange, withText text: String) {
        var editedLines: Set<DocumentLineNode> = []
        let nsText = text as NSString
        string.replaceCharacters(in: range, with: text)
        lineManager.removeCharacters(in: range, editedLines: &editedLines)
        lineManager.insert(nsText, at: range.location, editedLines: &editedLines)
        selectedTextRange = NSRange(location: range.location + text.utf16.count, length: 0)
        updateStrings(on: editedLines)
        setNeedsDisplay()
    }

    func text(in range: NSRange) -> String? {
        if range.location >= 0 && range.location + range.length <= string.length {
            return string.substring(with: range)
        } else {
            return nil
        }
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
        let textRenderer = getTextRenderer(for: line)
        let range = NSRange(location: line.location, length: line.value)
        let lineString = string.substring(with: range) as NSString
        textRenderer.setString(lineString)
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
                textRenderer.setString(substring)
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
