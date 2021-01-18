//
//  EditorLineView.swift
//  
//
//  Created by Simon Støvring on 18/01/2021.
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

final class EditorLineView: UIView {
    private(set) var totalHeight: CGFloat = 0
    var lineWidth: CGFloat = 0
    var textColor: UIColor?
    var font: UIFont?

    private var typesetter: CTTypesetter?
    private var preparedLines: [PreparedLine] = []
    private let syntaxHighlightController: SyntaxHighlightController
    private let queue = OperationQueue()
    private var attributedString: CFMutableAttributedString?

    init(syntaxHighlightController: SyntaxHighlightController) {
        self.syntaxHighlightController = syntaxHighlightController
        super.init(frame: .zero)
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        let context = UIGraphicsGetCurrentContext()!
        context.textMatrix = .identity
        context.translateBy(x: 0, y: frame.height)
        context.scaleBy(x: 1, y: -1)
        drawPreparedLines(to: context)
    }

    func prepare(with string: NSString) {
        reset()
        attributedString = CFAttributedStringCreateMutable(kCFAllocatorDefault, string.length)
        if let attributedString = attributedString {
            CFAttributedStringReplaceString(attributedString, CFRangeMake(0, 0), string)
            applyDefaultAttributes()
        }
        recreateTypesetter()
    }

    func syntaxHighlight(documentRange: NSRange) {
        queue.cancelAllOperations()
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak operation, weak self] in
            if let operation = operation, !operation.isCancelled {
                self?.syntaxHighlight(documentRange: documentRange, using: operation)
            }
        }
        queue.addOperation(operation)
    }
}

private extension EditorLineView {
    private func reset() {
        queue.cancelAllOperations()
        preparedLines = []
        totalHeight = 0
        typesetter = nil
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

    private func drawPreparedLines(to context: CGContext) {
        for preparedLine in preparedLines {
            let yPosition = preparedLine.descent + (frame.height - preparedLine.yPosition - preparedLine.lineHeight)
            context.textPosition = CGPoint(x: 0, y: yPosition)
            CTLineDraw(preparedLine.line, context)
        }
    }

    private func syntaxHighlight(documentRange: NSRange, using operation: Operation) {
        if case let .success(captures) = syntaxHighlightController.captures(in: documentRange) {
            if !operation.isCancelled {
                DispatchQueue.main.sync {
                    if !operation.isCancelled {
                        let attributes = self.syntaxHighlightController.attributes(for: captures, in: documentRange)
                        self.reset()
                        self.apply(attributes)
                        self.recreateTypesetter()
                        self.setNeedsDisplay()
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

    private func apply(_ attributes: [EditorTextRendererAttributes]) {
        guard let attributedString = attributedString else {
            return
        }
        CFAttributedStringBeginEditing(attributedString)
        for attribute in attributes {
            let range = CFRangeMake(attribute.range.location, attribute.range.length)
            var rawAttributes: [NSAttributedString.Key: Any] = [:]
            rawAttributes[.foregroundColor] = attribute.textColor ?? textColor
            rawAttributes[.font] = attribute.font ?? font
            CFAttributedStringSetAttributes(attributedString, range, rawAttributes as CFDictionary, true)
        }
        CFAttributedStringEndEditing(attributedString)
    }
}
