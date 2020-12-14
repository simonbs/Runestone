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
    func editorGutterController(_ controller: EditorGutterController, substringIn range: NSRange) -> String?
    func editorGutterController(_ controller: EditorGutterController, positionOfLineContainingCharacterAt location: Int) -> ObjCLinePosition?
}

final class EditorGutterController {
    weak var delegate: EditorGutterControllerDelegate?
    var theme: EditorTheme
    var font: UIFont!
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
        guard let delegate = delegate, let layoutManager = layoutManager, let textStorage = textStorage, let textContainer = textContainer else {
            return
        }
        let entireGlyphRange = layoutManager.glyphRange(forBoundingRect: rect, in: textContainer)
        let startLinePosition = textStorage.positionOfLine(containingCharacterAt: entireGlyphRange.location)
        let endLinePosition = textStorage.positionOfLine(containingCharacterAt: entireGlyphRange.location + entireGlyphRange.length)
        if let startLinePosition = startLinePosition, let endLinePosition = endLinePosition {
            for lineNumber in startLinePosition.lineNumber ... endLinePosition.lineNumber {
                let lineLocation = textStorage.locationOfLine(withLineNumber: lineNumber)
                let isHighlightedLine = shouldHighlightLineNumber(lineNumber, inRangeOfSelectedLines: highlightedRange)
                let glyphRange = NSRange(location: lineLocation, length: 1)
                let glyphRect: CGRect
                let lastCharacter = delegate.editorGutterController(self, substringIn: glyphRange)
                if lastCharacter == nil {
                    // We're on the last line in editor and the line is empty. We're handling two cases here:
                    // 1. The last line is also the first line, in which case we don't know the height of the line
                    //    but we cant use the line height of the font instead.
                    // 2. The previous line ended with a line break, and we're currently on an empty line.
                    //    In this case we can take half of the line's bounding rect as the line height.
                    if lineNumber == 1 {
                        glyphRect = CGRect(x: 0, y: 0, width: 0, height: font.lineHeight)
                    } else {
                        let previousGlyphRange = NSRange(location: glyphRange.location - 1, length: 1)
                        let boundingRect = layoutManager.boundingRect(forGlyphRange: previousGlyphRange, in: textContainer)
                        let lineHeight = boundingRect.height / 2
                        glyphRect = CGRect(x: boundingRect.minX, y: boundingRect.minY + lineHeight, width: boundingRect.width, height: lineHeight)
                    }
                } else {
                    glyphRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                }
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
        let textYPosition = rect.minY + (font.lineHeight - textSize.height) / 2
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
        guard let startLinePosition = delegate?.editorGutterController(self, positionOfLineContainingCharacterAt: selectedRange.location) else {
            return nil
        }
        let endLocation = selectedRange.location + selectedRange.length
        if selectedRange.length > 0, let endLinePosition = delegate?.editorGutterController(self, positionOfLineContainingCharacterAt: endLocation) {
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
}
