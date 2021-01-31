//
//  TextRenderer.swift
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

protocol TextRendererDelegate: AnyObject {
    func textRenderer(_ textRenderer: TextRenderer, stringIn range: NSRange) -> String
    func textRendererDidUpdateSyntaxHighlighting(_ textRenderer: TextRenderer)
}

final class TextRenderer {
    private enum SyntaxHighlightState {
        case notHighlighted
        case highlighting
        case highlighted
    }

    struct SelectionRect {
        let rect: CGRect
        let range: NSRange

        init(rect: CGRect, range: NSRange) {
            self.rect = rect
            self.range = range
        }
    }

    weak var delegate: TextRendererDelegate?
    private(set) var preferredHeight: CGFloat = 0
    var frame: CGRect = .zero
    var lineWidth: CGFloat = 0
    var lineID: DocumentLineNodeID?
    var documentRange: NSRange?
    var documentByteRange: ByteRange?
    var theme: EditorTheme = DefaultEditorTheme()
    var invisibleCharacterConfiguration = InvisibleCharacterConfiguration()

    private var isInvalid = true
    private var string: String?
    private var attributedString: CFMutableAttributedString?
    private var typesetter: CTTypesetter?
    private var preparedLines: [PreparedLine] = []
    private let syntaxHighlightController: SyntaxHighlightController
    private var syntaxHighlightState: SyntaxHighlightState = .notHighlighted
    private let syntaxHighlightQueue: OperationQueue
    private var currentSyntaxHighlightOperation: Operation?
    private var captures: [Capture]?
    private var lineHeight: CGFloat {
        return theme.font.lineHeight
    }

    init(syntaxHighlightController: SyntaxHighlightController, syntaxHighlightQueue: OperationQueue) {
        self.syntaxHighlightController = syntaxHighlightController
        self.syntaxHighlightQueue = syntaxHighlightQueue
    }
}

// MARK: - Preparation
extension TextRenderer {
    func invalidate() {
        cancelHighlightOperation()
        isInvalid = true
    }

    func prepareToDraw() {
        if isInvalid, let documentRange = documentRange {
            captures = nil
            syntaxHighlightState = .notHighlighted
            string = delegate!.textRenderer(self, stringIn: documentRange)
            recreateAttributedString()
            applyDefaultAttributes()
            recreateTypesetter()
            prepareLines()
            isInvalid = false
        }
    }

    private func cancelHighlightOperation() {
        if syntaxHighlightState == .highlighting {
            syntaxHighlightState = .notHighlighted
        }
        currentSyntaxHighlightOperation?.cancel()
        currentSyntaxHighlightOperation = nil
    }

    private func recreateAttributedString() {
        if let string = string, let attributedString = CFAttributedStringCreateMutable(kCFAllocatorDefault, string.utf16.count) {
            self.attributedString = attributedString
            CFAttributedStringReplaceString(attributedString, CFRangeMake(0, 0), string as CFString)
        } else {
            attributedString = nil
        }
    }

    private func recreateTypesetter() {
        if let attributedString = attributedString {
            typesetter = CTTypesetterCreateWithAttributedString(attributedString)
        } else {
            typesetter = nil
        }
    }

    private func prepareLines() {
        preparedLines = []
        preferredHeight = 0
        guard let typesetter = typesetter else {
            return
        }
        guard let attributedString = attributedString else {
            return
        }
        let stringLength = CFAttributedStringGetLength(attributedString)
        guard stringLength > 0 else {
            preferredHeight = lineHeight
            return
        }
        var nextYPosition: CGFloat = 0
        var startOffset = 0
        while startOffset < stringLength {
            let length = CTTypesetterSuggestLineBreak(typesetter, startOffset, Double(lineWidth))
            let range = CFRangeMake(startOffset, length)
            let line = CTTypesetterCreateLine(typesetter, range)
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
            let lineHeight = ascent + descent + leading
            let preparedLine = PreparedLine(line: line, descent: descent, lineHeight: lineHeight, yPosition: nextYPosition)
            preparedLines.append(preparedLine)
            nextYPosition += lineHeight
            startOffset += length
        }
        preferredHeight = ceil(nextYPosition)
    }
}

// MARK: - Drawing
extension TextRenderer {
    func draw(in context: CGContext) {
        drawBackgrounds(to: context)
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: frame.height)
        context.scaleBy(x: 1, y: -1)
        drawLines(to: context)
        context.restoreGState()
    }

    private func drawBackgrounds(to context: CGContext) {
        if invisibleCharacterConfiguration.showTabs || invisibleCharacterConfiguration.showSpaces || invisibleCharacterConfiguration.showLineBreaks {
            for preparedLine in preparedLines {
                drawInvisibleCharacters(in: preparedLine, to: context)
            }
        }
    }

    private func drawLines(to context: CGContext) {
        for preparedLine in preparedLines {
            let yPosition = preparedLine.descent + (frame.height - preparedLine.yPosition - preparedLine.lineHeight)
            context.textPosition = CGPoint(x: 0, y: yPosition)
            CTLineDraw(preparedLine.line, context)
        }
    }

    private func drawInvisibleCharacters(in preparedLine: PreparedLine, to context: CGContext) {
        guard let string = string else {
            return
        }
        let textRange = CTLineGetStringRange(preparedLine.line)
        let stringRange = Range(NSRange(location: textRange.location, length: textRange.length), in: string)!
        let lineString = string[stringRange]
        for (index, substring) in lineString.enumerated() {
            if invisibleCharacterConfiguration.showSpaces && substring == Symbol.Character.space {
                let xPosition = round(CTLineGetOffsetForStringIndex(preparedLine.line, index, nil))
                let point = CGPoint(x: CGFloat(xPosition), y: preparedLine.yPosition)
                draw(invisibleCharacterConfiguration.spaceSymbol, at: point)
            } else if invisibleCharacterConfiguration.showTabs && substring == Symbol.Character.tab {
                let xPosition = round(CTLineGetOffsetForStringIndex(preparedLine.line, index, nil))
                let point = CGPoint(x: CGFloat(xPosition), y: preparedLine.yPosition)
                draw(invisibleCharacterConfiguration.tabSymbol, at: point)
            } else if invisibleCharacterConfiguration.showLineBreaks && substring == Symbol.Character.lineFeed {
                let xPosition = round(CTLineGetTypographicBounds(preparedLine.line, nil, nil, nil))
                let point = CGPoint(x: CGFloat(xPosition), y: preparedLine.yPosition)
                draw(invisibleCharacterConfiguration.lineBreakSymbol, at: point)
            }
        }
    }

    private func draw(_ symbol: String, at point: CGPoint) {
        let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: theme.invisibleCharactersColor, .font: theme.font as Any]
        let size = symbol.size(withAttributes: attrs)
        let rect = CGRect(x: point.x, y: point.y, width: size.width, height: size.height)
        symbol.draw(in: rect, withAttributes: attrs)
    }
}

// MARK: - Appearance
extension TextRenderer {
    func syntaxHighlight() {
        guard syntaxHighlightState == .notHighlighted else {
            return
        }
        guard syntaxHighlightController.canHighlight else {
            return
        }
        syntaxHighlightState = .highlighting
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak operation, weak self] in
            if let operation = operation, !operation.isCancelled {
                self?.syntaxHighlight(using: operation)
            }
        }
        currentSyntaxHighlightOperation = operation
        syntaxHighlightQueue.addOperation(operation)
    }

    private func syntaxHighlight(using operation: Operation) {
        if let documentByteRange = documentByteRange, case let .success(captures) = syntaxHighlightController.captures(in: documentByteRange) {
            if !operation.isCancelled {
                DispatchQueue.main.sync {
                    if !operation.isCancelled {
                        self.captures = captures
                        self.applyAttributes(for: captures)
                        self.recreateTypesetter()
                        self.prepareLines()
                        self.syntaxHighlightState = .highlighted
                        self.delegate?.textRendererDidUpdateSyntaxHighlighting(self)
                    }
                }
            }
        }
    }

    private func applyDefaultAttributes() {
        guard let attributedString = attributedString else {
            return
        }
        let entireRange = CFRangeMake(0, CFAttributedStringGetLength(attributedString))
        var rawAttributes: [NSAttributedString.Key: Any] = [:]
        rawAttributes[.foregroundColor] = theme.textColor
        rawAttributes[.font] = theme.font
        CFAttributedStringSetAttributes(attributedString, entireRange, rawAttributes as CFDictionary, true)
    }

    private func applyAttributes(for captures: [Capture]) {
        if let documentRange = documentByteRange {
            let attributes = syntaxHighlightController.attributes(for: captures, localTo: documentRange)
            apply(attributes)
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
                rawAttributes[.foregroundColor] = token.textColor ?? theme.textColor
                rawAttributes[.font] = token.font ?? theme.font
                CFAttributedStringSetAttributes(attributedString, cfRange, rawAttributes as CFDictionary, true)
            }
        }
        CFAttributedStringEndEditing(attributedString)
    }
}

// MARK: - UITextInput
extension TextRenderer {
    func caretRect(atIndex index: Int) -> CGRect {
        for preparedLine in preparedLines {
            let lineRange = CTLineGetStringRange(preparedLine.line)
            let localIndex = index - lineRange.location
            if localIndex >= 0 && localIndex <= lineRange.length {
                let xPos = CTLineGetOffsetForStringIndex(preparedLine.line, index, nil)
                return CGRect(x: xPos, y: preparedLine.yPosition, width: Caret.width, height: preparedLine.lineHeight)
            }
        }
        return CGRect(x: 0, y: 0, width: Caret.width, height: lineHeight)
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

    func firstRect(for range: NSRange) -> CGRect {
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
        return CGRect(x: 0, y: 0, width: 0, height: lineHeight)
    }

    func closestIndex(to point: CGPoint) -> Int {
        var closestPreparedLine = preparedLines.last
        for preparedLine in preparedLines {
            let lineMaxY = preparedLine.yPosition + preparedLine.lineHeight
            if point.y <= lineMaxY {
                closestPreparedLine = preparedLine
                break
            }
        }
        if let closestPreparedLine = closestPreparedLine {
            return CTLineGetStringIndexForPosition(closestPreparedLine.line, point)
        } else {
            return 0
        }
    }
}
