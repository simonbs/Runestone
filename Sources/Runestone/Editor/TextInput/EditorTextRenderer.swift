//
//  EditorTextRenderer.swift
//  
//
//  Created by Simon Støvring on 23/01/2021.
//

import UIKit

private final class PreparedLine {
    let line: CTLine
    let descent: CGFloat
    let lineHeight: CGFloat
    let yPosition: CGFloat

    init(line: CTLine, descent: CGFloat, lineHeight: CGFloat, yPosition: CGFloat) {
        self.line = line
        self.descent = descent
        self.lineHeight = lineHeight
        self.yPosition = yPosition
    }
}

protocol EditorTextRendererDelegate: AnyObject {
    func editorTextRendererDidUpdateSyntaxHighlighting(_ textRenderer: EditorTextRenderer)
}

final class EditorTextRenderer {
    struct SelectionRect {
        let rect: CGRect
        let range: NSRange

        init(rect: CGRect, range: NSRange) {
            self.rect = rect
            self.range = range
        }
    }

    weak var delegate: EditorTextRendererDelegate?
    private(set) var totalHeight: CGFloat = 0
    private(set) var lineID: DocumentLineNodeID?
    var lineWidth: CGFloat = 0
    var textColor: UIColor?
    var font: UIFont?

    private var string: String?
    private var typesetter: CTTypesetter?
    private var preparedLines: [PreparedLine] = []
    private let syntaxHighlightController: SyntaxHighlightController
    private var attributedString: CFMutableAttributedString?
    private var isHighlighted = false
    private let syntaxHighlightQueue: OperationQueue
    private var currentSyntaxHighlightOperation: Operation?

    init(syntaxHighlightController: SyntaxHighlightController, syntaxHighlightQueue: OperationQueue) {
        self.syntaxHighlightController = syntaxHighlightController
        self.syntaxHighlightQueue = syntaxHighlightQueue
    }

    func draw(in context: CGContext) {
        context.textMatrix = .identity
        context.translateBy(x: 0, y: totalHeight)
        context.scaleBy(x: 1, y: -1)
        drawPreparedLines(to: context)
    }

    func prepareForReuse() {
        currentSyntaxHighlightOperation?.cancel()
        currentSyntaxHighlightOperation = nil
        string = nil
        lineID = nil
        attributedString = nil
        preparedLines = []
        totalHeight = 0
        typesetter = nil
        isHighlighted = false
    }

    func show(_ string: String, fromLineWithID lineID: DocumentLineNodeID) {
        guard hasChanged(from: string, inLineWithID: lineID) else {
            return
        }
        prepareForReuse()
        self.string = string
        self.lineID = lineID
        attributedString = CFAttributedStringCreateMutable(kCFAllocatorDefault, string.utf16.count)
        if let attributedString = attributedString {
            CFAttributedStringReplaceString(attributedString, CFRangeMake(0, 0), string as CFString)
            applyDefaultAttributes()
            if let cachedAttributes = syntaxHighlightController.cachedAttributes(for: lineID) {
                apply(cachedAttributes)
                isHighlighted = true
            }
            recreateTypesetter()
        }
    }

    func syntaxHighlight(_ documentRange: ByteRange, inLineWithID lineID: DocumentLineNodeID) {
        guard !isHighlighted else {
            return
        }
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak operation, weak self] in
            if let operation = operation, !operation.isCancelled {
                self?.syntaxHighlight(documentRange: documentRange, inLineWithID: lineID, using: operation)
            }
        }
        currentSyntaxHighlightOperation = operation
        syntaxHighlightQueue.addOperation(operation)
    }

    func caretRect(atIndex index: Int) -> CGRect {
        for preparedLine in preparedLines {
            let lineRange = CTLineGetStringRange(preparedLine.line)
            let localIndex = index - lineRange.location
            if localIndex >= 0 && localIndex <= lineRange.length {
                let xPos = CTLineGetOffsetForStringIndex(preparedLine.line, index, nil)
                return CGRect(x: xPos, y: preparedLine.yPosition, width: EditorCaret.width, height: preparedLine.lineHeight)
            }
        }
        return CGRect(x: 0, y: 0, width: EditorCaret.width, height: EditorCaret.defaultHeight(for: font))
    }

    func selectionRects(in range: NSRange) -> [SelectionRect] {
        var selectionRects: [SelectionRect] = []
        for preparedLine in preparedLines {
            let line = preparedLine.line
            let _lineRange = CTLineGetStringRange(line)
            let lineRange = NSRange(location: _lineRange.location, length: _lineRange.length)
            let selectionIntersection = range.intersection(lineRange)
            if let selectionIntersection = selectionIntersection {
                let xStart = CTLineGetOffsetForStringIndex(line, selectionIntersection.location, nil)
                let xEnd = CTLineGetOffsetForStringIndex(line, selectionIntersection.location + selectionIntersection.length, nil)
                let yPos = preparedLine.yPosition
                let rect = CGRect(x: xStart, y: yPos, width: xEnd - xStart, height: preparedLine.lineHeight)
                let selectionRect = SelectionRect(rect: rect, range: selectionIntersection)
                selectionRects.append(selectionRect)
            }
        }
        return selectionRects
    }

    func firstRect(for range: NSRange) -> CGRect? {
        for preparedLine in preparedLines {
            let line = preparedLine.line
            let lineRange = CTLineGetStringRange(line)
            let index = range.location
            if index >= 0 && index <= lineRange.length {
                let finalIndex = min(lineRange.location + lineRange.length, range.location + range.length)
                let xStart = CTLineGetOffsetForStringIndex(line, index, nil)
                let xEnd = CTLineGetOffsetForStringIndex(line, finalIndex, nil)
                return CGRect(x: xStart, y: preparedLine.yPosition, width: xEnd - xStart, height: preparedLine.lineHeight)
            }
        }
        return nil
    }

    func closestIndex(to point: CGPoint) -> Int? {
        for preparedLine in preparedLines {
            if point.y > preparedLine.yPosition {
                return CTLineGetStringIndexForPosition(preparedLine.line, point)
            }
        }
        return nil
    }
}

private extension EditorTextRenderer {
    private func hasChanged(from string: String, inLineWithID lineID: DocumentLineNodeID) -> Bool {
        return string != self.string || lineID != self.lineID
    }

    private func recreateTypesetter() {
        if let attributedString = attributedString {
            typesetter = CTTypesetterCreateWithAttributedString(attributedString)
            if let typesetter = typesetter {
                prepareLines(in: typesetter, lineWidth: Double(lineWidth))
            }
        }
    }

    private func prepareLines(in typesetter: CTTypesetter, lineWidth: Double) {
        guard let attributedString = attributedString else {
            return
        }
        totalHeight = 0
        let stringLength = CFAttributedStringGetLength(attributedString)
        var startOffset = 0
        while startOffset < stringLength {
            let length = CTTypesetterSuggestLineBreak(typesetter, startOffset, lineWidth)
            let range = CFRangeMake(startOffset, length)
            let line = CTTypesetterCreateLine(typesetter, range)
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
            let lineHeight = ascent + descent + leading
            let preparedLine = PreparedLine(line: line, descent: descent, lineHeight: lineHeight, yPosition: totalHeight)
            preparedLines.append(preparedLine)
            totalHeight += lineHeight
            startOffset += length
        }
    }

    private func syntaxHighlight(documentRange: ByteRange, inLineWithID lineID: DocumentLineNodeID, using operation: Operation) {
        if case let .success(captures) = syntaxHighlightController.captures(in: documentRange) {
            if !operation.isCancelled {
                DispatchQueue.main.sync {
                    if !operation.isCancelled {
                        self.syntaxHighlight(using: captures, in: documentRange, lineID: lineID)
                    }
                }
            }
        }
    }

    private func syntaxHighlight(using captures: [Capture], in documentRange: ByteRange, lineID: DocumentLineNodeID) {
        preparedLines = []
        totalHeight = 0
        typesetter = nil
        let attributes = syntaxHighlightController.attributes(for: captures, localTo: documentRange)
        syntaxHighlightController.cache(attributes, for: lineID)
        apply(attributes)
        recreateTypesetter()
        isHighlighted = true
        delegate?.editorTextRendererDidUpdateSyntaxHighlighting(self)
    }

    private func applyDefaultAttributes() {
        guard let attributedString = attributedString else {
            return
        }
        let entireRange = CFRangeMake(0, CFAttributedStringGetLength(attributedString))
        var rawAttributes: [NSAttributedString.Key: Any] = [:]
        if let textColor = textColor {
            rawAttributes[.foregroundColor] = textColor
        }
        if let font = font {
            rawAttributes[.font] = font
        }
        if !rawAttributes.isEmpty {
            CFAttributedStringSetAttributes(attributedString, entireRange, rawAttributes as CFDictionary, true)
        }
    }

    private func apply(_ tokens: [SyntaxHighlightToken]) {
        guard let attributedString = attributedString else {
            return
        }
        CFAttributedStringBeginEditing(attributedString)
        for token in tokens {
            if let range = string?.range(from: token.range) {
                let cfRange = CFRangeMake(range.location, range.length)
                var rawAttributes: [NSAttributedString.Key: Any] = [:]
                rawAttributes[.foregroundColor] = token.textColor ?? textColor
                rawAttributes[.font] = token.font ?? font
                CFAttributedStringSetAttributes(attributedString, cfRange, rawAttributes as CFDictionary, true)
            }
        }
        CFAttributedStringEndEditing(attributedString)
    }

    private func drawPreparedLines(to context: CGContext) {
        for preparedLine in preparedLines {
            let yPosition = preparedLine.descent + (totalHeight - preparedLine.yPosition - preparedLine.lineHeight)
            context.textPosition = CGPoint(x: 0, y: yPosition)
            CTLineDraw(preparedLine.line, context)
        }
    }
}
