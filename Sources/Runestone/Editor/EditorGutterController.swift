//
//  File.swift
//  
//
//  Created by Simon Støvring on 12/12/2020.
//

import UIKit
import RunestoneTextStorage

protocol EditorGutterControllerDelegate: AnyObject {
    func isTextViewFirstResponder(_ controller: EditorGutterController) -> Bool
    func widthOfTextView(_ controller: EditorGutterController) -> CGFloat
    func selectedRangeInTextView(_ controller: EditorGutterController) -> NSRange
    func numberOfLines(in controller: EditorGutterController) -> Int
    func editorGutterController(_ controller: EditorGutterController, positionOfCharacterAt location: Int) -> ObjCLinePosition?
    func editorGutterController(_ controller: EditorGutterController, locationOfLineWithLineNumber lineNumber: Int) -> Int
}

final class EditorGutterController {
    weak var delegate: EditorGutterControllerDelegate?
    var theme: EditorTheme
    var lineNumberFont: UIFont?
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
    private var gutterWidth: CGFloat = 0
    private var previousExlusionPath: UIBezierPath?
    private var numberOfLines: Int {
        return delegate?.numberOfLines(in: self) ?? 0
    }
    private var textViewWidth: CGFloat {
        return delegate?.widthOfTextView(self) ?? 0
    }
    private var isTextViewFirstResponder: Bool {
        return delegate?.isTextViewFirstResponder(self) ?? false
    }

    init(layoutManager: NSLayoutManager, textStorage: EditorTextStorage, textContainer: NSTextContainer, theme: EditorTheme) {
        self.layoutManager = layoutManager
        self.textStorage = textStorage
        self.textContainer = textContainer
        self.theme = theme
    }

    func reset() {
        if showLineNumbers, let textContainer = textContainer {
            let oldGutterWidth = gutterWidth
            gutterWidth = widthOfGutter(in: textContainer)
            if gutterWidth != oldGutterWidth {
                updateExlusionPath(in: textContainer)
            }
        } else {
            removeGutter()
        }
    }

    func drawGutterBackground(in rect: CGRect) {
        if showLineNumbers {
            let gutterRect = CGRect(x: 0, y: rect.minY, width: gutterWidth, height: rect.height)
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
    }

    func draw(_ lineFragment: EditorLineFragment) {
        let shouldDraw = showLineNumbers || highlightSelectedLine
        guard shouldDraw, let delegate = delegate, let layoutManager = layoutManager else {
            return
        }
        if let linePosition = delegate.editorGutterController(self, positionOfCharacterAt: lineFragment.glyphRange.location) {
            let lineLocation = delegate.editorGutterController(self, locationOfLineWithLineNumber: linePosition.lineNumber)
            if lineFragment.glyphRange.location == lineLocation {
                let lineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: lineFragment.glyphRange.location, effectiveRange: nil)
                let lineYPosition = lineFragmentRect.minY + textContainerInset.top
                let lineRect = CGRect(x: 0, y: lineYPosition, width: textViewWidth, height: lineFragmentRect.height)
                let lineRange = NSRange(location: lineLocation, length: linePosition.length)
                drawLine(withLineNumber: linePosition.lineNumber, in: lineRect, spanning: lineRange)
            }
        }
    }

    func drawExtraLineIfNecessary() {
        let shouldDraw = showLineNumbers || highlightSelectedLine
        if shouldDraw, let layoutManager = layoutManager, let textStorage = textStorage {
            let extraLineFragmentUsedRect = layoutManager.extraLineFragmentUsedRect
            if extraLineFragmentUsedRect.size != .zero {
                let lineYPosition = extraLineFragmentUsedRect.minY + textContainerInset.top
                let lineHeight = lineNumberFont?.lineHeight ?? extraLineFragmentUsedRect.height
                let lineRect = CGRect(x: 0, y: lineYPosition, width: gutterWidth, height: lineHeight)
                let lineRange = NSRange(location: textStorage.length, length: 1)
                drawLine(withLineNumber: numberOfLines, in: lineRect, spanning: lineRange)
            }
        }
    }
}

private extension EditorGutterController {
    private func removeGutter() {
        gutterWidth = 0
        previousMaximumCharacterCount = 0
        let exclusionPaths = textContainer?.exclusionPaths ?? []
        textContainer?.exclusionPaths = exclusionPaths.filter { $0 !== previousExlusionPath }
        previousExlusionPath = nil
    }

    private func widthOfGutter(in textContainer: NSTextContainer) -> CGFloat {
        let stringRepresentation = String(describing: numberOfLines)
        let maximumCharacterCount = max(stringRepresentation.count, Int(accommodateMinimumCharacterCountInLineNumbers))
        guard maximumCharacterCount != previousMaximumCharacterCount else {
            return gutterWidth
        }
        let wideLineNumberString = String(repeating: "8", count: maximumCharacterCount)
        let wideLineNumberNSString = wideLineNumberString as NSString
        let size = wideLineNumberNSString.size(withAttributes: [.font: theme.lineNumberFont])
        let gutterWidth = ceil(size.width) + lineNumberLeadingMargin + lineNumberTrailingMargin
        previousMaximumCharacterCount = maximumCharacterCount
        return gutterWidth
    }

    private func updateExlusionPath(in textContainer: NSTextContainer) {
        let exclusionRect = CGRect(x: 0, y: 0, width: gutterWidth, height: .greatestFiniteMagnitude)
        var exlusionPaths = textContainer.exclusionPaths.filter { $0 !== previousExlusionPath }
        let exlusionPath = UIBezierPath(rect: exclusionRect)
        exlusionPaths.append(exlusionPath)
        textContainer.exclusionPaths = exlusionPaths
        previousExlusionPath = exlusionPath
    }

    private func shouldHighlineLine(spanning lineRange: NSRange) -> Bool {
        if highlightSelectedLine, isTextViewFirstResponder, let selectedRange = delegate?.selectedRangeInTextView(self) {
            let selectedStartLocation = selectedRange.location
            let selectedEndLocation = selectedRange.location + selectedRange.length
            let lineStartLocation = lineRange.location
            let lineEndLocation = lineRange.location + lineRange.length
            return (selectedStartLocation >= lineStartLocation && selectedStartLocation <= lineEndLocation)
                || (selectedEndLocation >= lineStartLocation && selectedEndLocation <= lineEndLocation)
                || (selectedStartLocation <= lineStartLocation && selectedEndLocation >= lineEndLocation)
        } else {
            return false
        }
    }

    private func drawLine(withLineNumber lineNumber: Int, in lineRect: CGRect, spanning lineRange: NSRange) {
        let isLineSelected = shouldHighlineLine(spanning: lineRange)
        if isLineSelected {
            let lineContentWidth = textViewWidth - gutterWidth
            let lineContentRect = CGRect(x: gutterWidth, y: lineRect.minY, width: lineContentWidth, height: lineRect.height)
            drawSelectedLineBackground(in: lineContentRect)
        }
        if showLineNumbers {
            let gutterRect = CGRect(x: 0, y: lineRect.minY, width: gutterWidth, height: lineRect.height)
            if isLineSelected {
                drawSelectedGutterBackground(in: gutterRect)
            }
            drawLineNumber(lineNumber, in: gutterRect, isHighlighted: isLineSelected)
        }
    }

    private func drawLineNumber(_ lineNumber: Int, in rect: CGRect, isHighlighted: Bool) {
        let textColor = isHighlighted ? theme.selectedLinesLineNumberColor : theme.lineNumberColor
        let text = String(describing: lineNumber) as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: theme.lineNumberFont, .foregroundColor: textColor]
        let textSize = text.size(withAttributes: attributes)
        let gutterRect = CGRect(x: 0, y: rect.minY, width: gutterWidth, height: rect.height)
        let textXPosition = gutterRect.width - textSize.width - lineNumberTrailingMargin
        let textYPosition = rect.minY + (rect.height - textSize.height) / 2
        let textRect = CGRect(x: textXPosition, y: textYPosition, width: textSize.width, height: textSize.height)
        text.draw(in: textRect, withAttributes: attributes)
    }

    private func drawSelectedGutterBackground(in rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        context?.setFillColor(theme.selectedLinesGutterBackgroundColor.cgColor)
        context?.fill(rect)
        context?.restoreGState()
    }

    private func drawSelectedLineBackground(in rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        context?.setFillColor(theme.selectedLinesBackgroundColor.cgColor)
        context?.fill(rect)
        context?.restoreGState()
    }
}
