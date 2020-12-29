//
//  GutterController.swift
//  
//
//  Created by Simon Støvring on 12/12/2020.
//

import UIKit
import RunestoneTextStorage

final class GutterController {
    weak var textView: UITextView?
    var theme: EditorTheme
    var lineNumberFont: UIFont?
    var lineNumberLeadingMargin: CGFloat = 7
    var lineNumberTrailingMargin: CGFloat = 7
    var showLineNumbers = false
    var highlightSelectedLine = false
    var accommodateMinimumCharacterCountInLineNumbers = 0
    var additionalTextContainerInset: UIEdgeInsets = .zero
    var shouldUpdateGutterWidth: Bool {
        return maximumLineNumberCharacterCount != previousMaximumLineNumberCharacterCount
            || textView?.safeAreaInsets.left != previousSafeAreaInset
    }

    private weak var lineManager: LineManager?
    private weak var layoutManager: NSLayoutManager?
    private weak var textContainer: NSTextContainer?
    private weak var textStorage: EditorTextStorage?
    private var previousMaximumLineNumberCharacterCount = 0
    private var previousSafeAreaInset: CGFloat?
    private var gutterWidth: CGFloat = 0
    private var maximumLineNumberCharacterCount: Int {
        let numberOfLines = lineManager?.lineCount ?? 0
        let stringRepresentation = String(describing: numberOfLines)
        return max(stringRepresentation.count, Int(accommodateMinimumCharacterCountInLineNumbers))
    }

    init(lineManager: LineManager, layoutManager: NSLayoutManager, textContainer: NSTextContainer, textStorage: EditorTextStorage, theme: EditorTheme) {
        self.lineManager = lineManager
        self.layoutManager = layoutManager
        self.textContainer = textContainer
        self.textStorage = textStorage
        self.theme = theme
    }

    func updateGutterWidth() {
        if showLineNumbers, let textContainer = textContainer {
            gutterWidth = widthOfGutter(in: textContainer)
        } else {
            gutterWidth = 0
            previousMaximumLineNumberCharacterCount = 0
        }
    }

    func updateTextContainerInset() {
        if gutterWidth > 0 {
            textView?.textContainerInset = UIEdgeInsets(
                top: additionalTextContainerInset.top,
                left: gutterWidth,
                bottom: additionalTextContainerInset.bottom,
                right: additionalTextContainerInset.right)
        } else {
            textView?.textContainerInset = additionalTextContainerInset
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
        guard shouldDraw, let textView = textView, let layoutManager = layoutManager, let textContainer = textContainer else {
            return
        }
        guard let linePosition = lineManager?.positionOfLine(containingCharacterAt: lineFragment.glyphRange.location) else {
            return
        }
        guard let lineLocation = lineManager?.locationOfLine(withLineNumber: linePosition.lineNumber) else {
            return
        }
        guard lineFragment.glyphRange.location == lineLocation else {
            return
        }
        let lineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: lineFragment.glyphRange.location, effectiveRange: nil)
        let lineRange = NSRange(location: lineLocation, length: linePosition.length)
        let isLineSelected = shouldHighlightLine(spanning: lineRange, forSelectedRange: textView.selectedRange)
        if isLineSelected {
            let entireLineRange = NSRange(location: lineLocation, length: linePosition.length)
            let lineBoundingRect = layoutManager.boundingRect(forGlyphRange: entireLineRange, in: textContainer)
            let lineBackgroundYPosition = lineBoundingRect.minY + additionalTextContainerInset.top
            let lineBackgroundRect = CGRect(x: gutterWidth, y: lineBackgroundYPosition, width: textView.bounds.width, height: lineBoundingRect.height)
            drawLineBackgrounds(in: lineBackgroundRect)
        }
        let gutterRect = CGRect(x: 0, y: lineFragmentRect.minY + additionalTextContainerInset.top, width: gutterWidth, height: lineFragmentRect.height)
        let textColor = isLineSelected ? theme.selectedLinesLineNumberColor : theme.lineNumberColor
        drawLineNumber(linePosition.lineNumber, in: gutterRect, textColor: textColor)
    }

    func drawExtraLineIfNecessary() {
        let shouldDraw = showLineNumbers || highlightSelectedLine
        if shouldDraw, let lineManager = lineManager, let layoutManager = layoutManager, let textStorage = textStorage {
            let extraLineFragmentUsedRect = layoutManager.extraLineFragmentUsedRect
            if extraLineFragmentUsedRect.size != .zero {
                let lineYPosition = extraLineFragmentUsedRect.minY + additionalTextContainerInset.top
                let lineHeight = lineNumberFont?.lineHeight ?? extraLineFragmentUsedRect.height
                let lineRect = CGRect(x: 0, y: lineYPosition, width: gutterWidth, height: lineHeight)
                let lineRange = NSRange(location: textStorage.length, length: 1)
                let isLineSelected = shouldHighlightLine(spanning: lineRange, forSelectedRange: textView?.selectedRange)
                if isLineSelected {
                    drawLineBackgrounds(in: lineRect)
                }
                let gutterRect = CGRect(x: 0, y: lineRect.minY, width: gutterWidth, height: lineRect.height)
                let textColor = isLineSelected ? theme.selectedLinesLineNumberColor : theme.lineNumberColor
                drawLineNumber(lineManager.lineCount, in: gutterRect, textColor: textColor)
            }
        }
    }
}

private extension GutterController {
    private func drawLineBackgrounds(in rect: CGRect) {
        guard let textView = textView else {
            return
        }
        // We only draw line backgrounds when the selected range is zero, meaning no characters are selected.
        // Highlighting the current lines when characters is selected looks strange and makes it difficult to see
        // what is the selected characters and what is the current lines.
        if textView.selectedRange.length == 0 {
            let lineContentRect = CGRect(x: gutterWidth, y: rect.minY, width: textView.bounds.width - gutterWidth, height: rect.height)
            drawSelectedLineBackground(in: lineContentRect)
        }
        if showLineNumbers {
            let gutterLineBoundingRect = CGRect(x: 0, y: rect.minY, width: gutterWidth, height: rect.height)
            drawSelectedGutterBackground(in: gutterLineBoundingRect)
        }
    }

    private func drawLineNumber(_ lineNumber: Int, in rect: CGRect, textColor: UIColor) {
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
        context?.setFillColor(theme.selectedLineBackgroundColor.cgColor)
        context?.fill(rect)
        context?.restoreGState()
    }

    private func widthOfGutter(in textContainer: NSTextContainer) -> CGFloat {
        let maximumCharacterCount = maximumLineNumberCharacterCount
        let safeAreaInset = textView?.safeAreaInsets.left ?? .zero
        guard maximumCharacterCount != previousMaximumLineNumberCharacterCount || safeAreaInset != previousSafeAreaInset else {
            return gutterWidth
        }
        let wideLineNumberString = String(repeating: "8", count: maximumCharacterCount)
        let wideLineNumberNSString = wideLineNumberString as NSString
        let size = wideLineNumberNSString.size(withAttributes: [.font: theme.lineNumberFont])
        let gutterWidth = safeAreaInset + ceil(size.width) + lineNumberLeadingMargin + lineNumberTrailingMargin
        previousMaximumLineNumberCharacterCount = maximumCharacterCount
        previousSafeAreaInset = safeAreaInset
        return gutterWidth
    }

    private func shouldHighlightLine(spanning lineRange: NSRange, forSelectedRange selectedRange: NSRange?) -> Bool {
        guard highlightSelectedLine, let textStorage = textStorage, let selectedRange = selectedRange, let textView = textView, textView.isFirstResponder else {
            return false
        }
        let selectedStartLocation = selectedRange.location
        var selectedEndLocation = selectedRange.location + selectedRange.length
        // Ensure we don't show the next line as selected when selecting the \n at the end of a line.
        if selectedRange.length > 0 && selectedEndLocation > 0 && selectedEndLocation <= textStorage.length {
            let substring = textStorage.substring(in: NSRange(location: selectedEndLocation - 1, length: 1))
            let selectionEndsWithLineBreak = substring == Symbol.lineFeed
            if selectionEndsWithLineBreak {
                // The selection ends with a \n, so we make the selection a character shorter when checking if the line is selected.
                selectedEndLocation -= 1
            }
        }
        let lineStartLocation = lineRange.location
        let lineEndLocation = lineRange.location + lineRange.length
        return (selectedStartLocation >= lineStartLocation && selectedStartLocation <= lineEndLocation)
            || (selectedEndLocation >= lineStartLocation && selectedEndLocation <= lineEndLocation)
            || (selectedStartLocation <= lineStartLocation && selectedEndLocation >= lineEndLocation)
    }
}
