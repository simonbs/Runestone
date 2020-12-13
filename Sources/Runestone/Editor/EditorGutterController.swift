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
}

final class EditorGutterController {
    weak var delegate: EditorGutterControllerDelegate?
    var theme: EditorTheme
    var lineNumberLeadingMargin: CGFloat = 7
    var lineNumberTrailingMargin: CGFloat = 7
    var showLineNumbers = false
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

    func drawGutter(in rect: CGRect) {
        if showLineNumbers, let delegate = delegate, let textContainer = textContainer {
            numberOfLines = delegate.numberOfLines(in: self)
            let oldGutterWidth = gutterWidth
            gutterWidth = widthOfGutter(in: textContainer)
            if gutterWidth != oldGutterWidth {
                updateExlusionPath(in: textContainer)
            }
            drawGutterBackground(in: rect)
            drawLineNumbers(in: rect)
        } else {
            numberOfLines = 0
            gutterWidth = 0
            let exclusionPaths = textContainer?.exclusionPaths ?? []
            textContainer?.exclusionPaths = exclusionPaths.filter { $0 !== previousExlusionPath }
            previousExlusionPath = nil
        }
    }
}

private extension EditorGutterController {
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

    private func drawLineNumbers(in rect: CGRect) {
        guard let delegate = delegate, let layoutManager = layoutManager, let textStorage = textStorage, let textContainer = textContainer else {
            return
        }
        let entireGlyphRange = layoutManager.glyphRange(forBoundingRect: rect, in: textContainer)
        let startLinePosition = textStorage.positionOfLine(containingCharacterAt: entireGlyphRange.location)
        let endLinePosition = textStorage.positionOfLine(containingCharacterAt: entireGlyphRange.location + entireGlyphRange.length)
        if let startLinePosition = startLinePosition, let endLinePosition = endLinePosition {
            for lineNumber in startLinePosition.lineNumber ... endLinePosition.lineNumber {
                let lineLocation = textStorage.locationOfLine(withLineNumber: lineNumber)
                let glyphRange = NSRange(location: lineLocation, length: 1)
                if lineNumber != 1 && lineNumber == numberOfLines && delegate.editorGutterController(self, substringIn: glyphRange) == nil {
                    let previousGlyphRange = NSRange(location: glyphRange.location - 1, length: 1)
                    let boundingRect = layoutManager.boundingRect(forGlyphRange: previousGlyphRange, in: textContainer)
                    let lineHeight = boundingRect.height / 2
                    let lineNumberRect = CGRect(x: boundingRect.minX, y: boundingRect.minY + lineHeight, width: boundingRect.width, height: lineHeight)
                    drawLineNumber(lineNumber, in: lineNumberRect)
                } else {
                    let lineNumberRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
                    drawLineNumber(lineNumber, in: lineNumberRect)
                }
            }
        }
    }

    private func drawLineNumber(_ lineNumber: Int, in rect: CGRect) {
        let text = String(describing: lineNumber) as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: theme.lineNumberFont, .foregroundColor: theme.lineNumberColor]
        let textSize = text.size(withAttributes: attributes)
        let gutterRect = CGRect(x: 0, y: rect.minY, width: gutterWidth, height: rect.height)
        let textXPosition = gutterRect.width - textSize.width - lineNumberTrailingMargin
        let textYPosition = rect.minY + textContainerInset.top
        let textRect = CGRect(x: textXPosition, y: textYPosition, width: textSize.width, height: textSize.height)
        text.draw(in: textRect, withAttributes: attributes)
    }
}
