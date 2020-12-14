//
//  File.swift
//  
//
//  Created by Simon Støvring on 12/12/2020.
//

import UIKit
import RunestoneTextStorage

protocol EditorGutterControllerDelegate: AnyObject {
    func numberOfLines(in controller: EditorGutterController) -> Int
    func editorGutterController(_ controller: EditorGutterController, positionOfCharacterAt location: Int) -> ObjCLinePosition?
    func editorGutterController(_ controller: EditorGutterController, locationOfLineWithLineNumber lineNumber: Int) -> Int
    func editorGutterController(_ controller: EditorGutterController, substringIn range: NSRange) -> String?
}

final class EditorGutterController {
    weak var delegate: EditorGutterControllerDelegate?
    var theme: EditorTheme
    var font: UIFont?
    var lineNumberLeadingMargin: CGFloat = 7
    var lineNumberTrailingMargin: CGFloat = 7
    var showLineNumbers = false
    var highlightSelectedLine = false
    var accommodateMinimumCharacterCountInLineNumbers = 0
    var textContainerInset: UIEdgeInsets = .zero

    private weak var layoutManager: NSLayoutManager?
    private weak var textStorage: EditorTextStorage?
    private weak var textContainer: NSTextContainer?
    private var previousMaximumCharacterCount = 0
    private var numberOfLines = 0
    private var gutterWidth: CGFloat = 0
    private var previousExlusionPath: UIBezierPath?

    init(layoutManager: NSLayoutManager, textStorage: EditorTextStorage, textContainer: NSTextContainer, theme: EditorTheme) {
        self.layoutManager = layoutManager
        self.textStorage = textStorage
        self.textContainer = textContainer
        self.theme = theme
    }

    func drawGutter(in rect: CGRect, isFirstResponder: Bool, selectedRange: NSRange) {
        let shouldDraw = showLineNumbers || highlightSelectedLine
        guard shouldDraw, let delegate = delegate, let textContainer = textContainer else {
            removeGutter()
            return
        }
        let highlightedRange = isFirstResponder ? getRangeOfSelectedLineNumbers(selectedRange: selectedRange) : nil
        if showLineNumbers {
            numberOfLines = delegate.numberOfLines(in: self)
            let oldGutterWidth = gutterWidth
            gutterWidth = widthOfGutter(in: textContainer)
            if gutterWidth != oldGutterWidth {
                updateExlusionPath(in: textContainer)
            }
            drawGutterBackground(in: rect)
        } else {
            removeGutter()
        }
        // To mazimize performance the drawLines function can draw two things:
        // 1. Line numbers in the gutter. Highlights them for the selected line.
        // 2. Background color on the selected lines.
        drawLines(in: rect, highlightedRange: highlightedRange)
    }
}

private extension EditorGutterController {
    private func removeGutter() {
        numberOfLines = 0
        gutterWidth = 0
        previousMaximumCharacterCount = 0
        let exclusionPaths = textContainer?.exclusionPaths ?? []
        textContainer?.exclusionPaths = exclusionPaths.filter { $0 !== previousExlusionPath }
        previousExlusionPath = nil
    }

    private func widthOfGutter(in textContainer: NSTextContainer) -> CGFloat {
        let stringRepresentation = String(describing: numberOfLines)
        let maximumCharacterCount = max(stringRepresentation.count, Int(accommodateMinimumCharacterCountInLineNumbers))
        if maximumCharacterCount != previousMaximumCharacterCount {
            let wideLineNumberString = String(repeating: "8", count: maximumCharacterCount)
            let wideLineNumberNSString = wideLineNumberString as NSString
            let size = wideLineNumberNSString.size(withAttributes: [.font: theme.lineNumberFont])
            let gutterWidth = ceil(size.width) + lineNumberLeadingMargin + lineNumberTrailingMargin
            previousMaximumCharacterCount = maximumCharacterCount
            return gutterWidth
        } else {
            return gutterWidth
        }
    }

    private func updateExlusionPath(in textContainer: NSTextContainer) {
        let exclusionRect = CGRect(x: 0, y: 0, width: gutterWidth, height: .greatestFiniteMagnitude)
        var exlusionPaths = textContainer.exclusionPaths.filter { $0 !== previousExlusionPath }
        let exlusionPath = UIBezierPath(rect: exclusionRect)
        exlusionPaths.append(exlusionPath)
        textContainer.exclusionPaths = exlusionPaths
        previousExlusionPath = exlusionPath
    }

    private func drawGutterBackground(in rect: CGRect) {
        let gutterRect = CGRect(x: 0, y: 0, width: gutterWidth, height: rect.height)
        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        context?.setFillColor(theme.gutterBackgroundColor.cgColor)
        context?.fill(gutterRect)
        if theme.gutterHairlineWidth > 0 {
            let hairlineRect = CGRect(x: gutterWidth - theme.gutterHairlineWidth, y: 0, width: theme.gutterHairlineWidth, height: rect.height)
            context?.setFillColor(theme.gutterHairlineColor.cgColor)
            context?.fill(hairlineRect)
        }
        context?.restoreGState()
    }

    private func drawLines(in rect: CGRect, highlightedRange: NSRange?) {
        guard let layoutManager = layoutManager, let textStorage = textStorage, let textContainer = textContainer else {
            return
        }
        let entireGlyphRange = layoutManager.glyphRange(forBoundingRect: rect, in: textContainer)
        let startLinePosition = textStorage.positionOfLine(containingCharacterAt: entireGlyphRange.location)
        let endLinePosition = textStorage.positionOfLine(containingCharacterAt: entireGlyphRange.location + entireGlyphRange.length)
        if let startLinePosition = startLinePosition, let endLinePosition = endLinePosition {
            for lineNumber in startLinePosition.lineNumber ... endLinePosition.lineNumber {
                let isHighlightedLine = shouldHighlightLineNumber(lineNumber, inRangeOfSelectedLines: highlightedRange)
                let glyphRect = rectangleOfLine(atLineNumber: lineNumber, textStorage: textStorage, textContainer: textContainer, layoutManager: layoutManager)
                let lineNumberRect = CGRect(x: 0, y: glyphRect.minY + textContainerInset.top, width: gutterWidth, height: glyphRect.height)
                if isHighlightedLine {
                    let entireLineRect = CGRect(x: gutterWidth, y: lineNumberRect.minY, width: rect.width - gutterWidth, height: lineNumberRect.height)
                    drawHighlightedLineBackground(in: entireLineRect)
                    if showLineNumbers {
                        drawHighlightedLineNumberBackground(in: lineNumberRect)
                    }
                }
                if showLineNumbers {
                    drawLineNumber(lineNumber, in: lineNumberRect, isHighlighted: isHighlightedLine)
                }
            }
        }
    }

    private func rectangleOfLine(
        atLineNumber lineNumber: Int,
        textStorage: EditorTextStorage,
        textContainer: NSTextContainer,
        layoutManager: NSLayoutManager) -> CGRect {
        guard lineNumber != 1 else {
            // Find rect of first line.
//            print("\(lineNumber): A")
            let lineHeight = font?.lineHeight ?? 0
            return CGRect(x: 0, y: 0, width: 0, height: lineHeight)
        }
        let lineLocation = textStorage.locationOfLine(withLineNumber: lineNumber)
        let firstGlyphRange = NSRange(location: lineLocation, length: 1)
        let preferredGlyphRect = layoutManager.boundingRect(forGlyphRange: firstGlyphRange, in: textContainer)
        if preferredGlyphRect == .zero {
            // Rect of glyph is zero. This happens on the last line when it's empty.
            let previousGlyphRange = NSRange(location: firstGlyphRange.location - 1, length: 1)
            let previousGlyphRect = layoutManager.boundingRect(forGlyphRange: previousGlyphRange, in: textContainer)
            let lineHeight = previousGlyphRect.height / 2
//            print("\(lineNumber): B")
            return CGRect(x: previousGlyphRect.minX, y: previousGlyphRect.minY + lineHeight, width: previousGlyphRect.width, height: lineHeight)
        } else if delegate?.editorGutterController(self, substringIn: firstGlyphRange) == Symbol.lineFeed {
            // The first character is a line break. This happens on lines that aren't the least line but contains only a line break.
            let previousLineLocation = delegate!.editorGutterController(self, locationOfLineWithLineNumber: lineNumber - 1)
            let previousLineFirstGlyphRange = NSRange(location: previousLineLocation, length: 1)
            let previousLineRect = layoutManager.boundingRect(forGlyphRange: previousLineFirstGlyphRange, in: textContainer)
//            print("\(lineNumber): C => \(previousLineLocation)")
            let lineHeight = previousLineRect.height
            return CGRect(x: previousLineRect.minX, y: previousLineRect.maxY, width: preferredGlyphRect.width, height: lineHeight)
        } else {
            // Handle any other line.
//            print("\(lineNumber): D")
            return preferredGlyphRect
        }
    }

    private func drawHighlightedLineBackground(in rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        context?.setFillColor(theme.gutterBackgroundColorOnSelectedLine.cgColor)
        context?.fill(rect)
        context?.restoreGState()
    }

    private func drawHighlightedLineNumberBackground(in rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        context?.setFillColor(theme.gutterBackgroundColorOnSelectedLine.cgColor)
        context?.fill(rect)
        context?.restoreGState()
    }

    private func drawLineNumber(_ lineNumber: Int, in rect: CGRect, isHighlighted: Bool) {
        let textColor = isHighlighted ? theme.lineNumberColorOnSelectedLine : theme.lineNumberColor
        let text = String(describing: lineNumber) as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: theme.lineNumberFont, .foregroundColor: textColor]
        let textSize = text.size(withAttributes: attributes)
        let gutterRect = CGRect(x: 0, y: rect.minY, width: gutterWidth, height: rect.height)
        let textXPosition = gutterRect.width - textSize.width - lineNumberTrailingMargin
        let textYPosition = rect.minY + (rect.height - textSize.height) / 2
        let textRect = CGRect(x: textXPosition, y: textYPosition, width: textSize.width, height: textSize.height)
        text.draw(in: textRect, withAttributes: attributes)
    }

    private func shouldHighlightLineNumber(_ lineNumber: Int, inRangeOfSelectedLines selectedLineRange: NSRange?) -> Bool {
        if let selectedLineRange = selectedLineRange {
            return lineNumber >= selectedLineRange.location && lineNumber <= selectedLineRange.location + selectedLineRange.length
        } else {
            return false
        }
    }

    private func getRangeOfSelectedLineNumbers(selectedRange: NSRange) -> NSRange? {
        guard highlightSelectedLine else {
            return nil
        }
        guard let startLinePosition = delegate?.editorGutterController(self, positionOfCharacterAt: selectedRange.location) else {
            return nil
        }
        let endLocation = selectedRange.location + selectedRange.length
        if selectedRange.length > 0, let endLinePosition = delegate?.editorGutterController(self, positionOfCharacterAt: endLocation) {
            let lineNumberLength = endLinePosition.lineNumber - startLinePosition.lineNumber
            return NSRange(location: startLinePosition.lineNumber, length: lineNumberLength)
        } else {
            return NSRange(location: startLinePosition.lineNumber, length: 0)
        }
    }

    private func height(of text: NSString) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [.font: theme.lineNumberFont]
        let textSize = text.size(withAttributes: attributes)
        return textSize.height
    }

    private func isEmptyLine(at range: NSRange) -> Bool {
        let str = delegate?.editorGutterController(self, substringIn: range)
        return str == nil || str == Symbol.lineFeed
    }
}
