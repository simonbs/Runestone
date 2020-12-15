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
    private enum LineHeightComputationApproach {
        case extraLine
        case lineBreak
        case `default`
    }

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
    private var numberOfLines: Int?
    private var gutterWidth: CGFloat = 0
    private var previousExlusionPath: UIBezierPath?

    init(layoutManager: NSLayoutManager, textStorage: EditorTextStorage, textContainer: NSTextContainer, theme: EditorTheme) {
        self.layoutManager = layoutManager
        self.textStorage = textStorage
        self.textContainer = textContainer
        self.theme = theme
    }

    func reset() {
        if let delegate = delegate {
            numberOfLines = delegate.numberOfLines(in: self)
        }
        prepareGutter()
    }

    func drawGutterBackground(in rect: CGRect) {
        guard showLineNumbers else {
            return
        }
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

    func draw(_ lineFragment: EditorLineFragment) {
        guard let delegate = delegate, let layoutManager = layoutManager else {
            return
        }
        if let linePosition = delegate.editorGutterController(self, positionOfCharacterAt: lineFragment.glyphRange.location) {
            let lineLocation = delegate.editorGutterController(self, locationOfLineWithLineNumber: linePosition.lineNumber)
            if lineFragment.glyphRange.location == lineLocation {
                let lineFragmentRect = layoutManager.lineFragmentRect(forGlyphAt: lineFragment.glyphRange.location, effectiveRange: nil)
                let lineNumberRect = CGRect(x: 0, y: lineFragmentRect.minY + textContainerInset.top, width: gutterWidth, height: lineFragmentRect.height)
                drawLineNumber(linePosition.lineNumber, in: lineNumberRect, isHighlighted: false)
            }
        }
    }

    func drawExtraLineIfNecessary() {
        if let layoutManager = layoutManager, let numberOfLines = numberOfLines {
            let extraLineFragmentUsedRect = layoutManager.extraLineFragmentUsedRect
            if extraLineFragmentUsedRect.size != .zero {
                let yPosition = extraLineFragmentUsedRect.minY + textContainerInset.top
                let lineHeight = font?.lineHeight ?? extraLineFragmentUsedRect.height
                let lineRect = CGRect(x: 0, y: yPosition, width: gutterWidth, height: lineHeight)
                drawLineNumber(numberOfLines, in: lineRect, isHighlighted: false)
            }
        }
    }
}

private extension EditorGutterController {
    private func prepareGutter() {
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

    private func removeGutter() {
        numberOfLines = nil
        gutterWidth = 0
        previousMaximumCharacterCount = 0
        let exclusionPaths = textContainer?.exclusionPaths ?? []
        textContainer?.exclusionPaths = exclusionPaths.filter { $0 !== previousExlusionPath }
        previousExlusionPath = nil
    }

    private func widthOfGutter(in textContainer: NSTextContainer) -> CGFloat {
        guard let numberOfLines = numberOfLines else {
            return gutterWidth
        }
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

//    private func drawLines(in rect: CGRect, highlightedRange: NSRange?) {
//        guard let layoutManager = layoutManager, let textStorage = textStorage, let textContainer = textContainer else {
//            return
//        }
//        let entireGlyphRange = layoutManager.glyphRange(forBoundingRect: rect, in: textContainer)
//        let startLinePosition = textStorage.positionOfLine(containingCharacterAt: entireGlyphRange.location)
//        let endLinePosition = textStorage.positionOfLine(containingCharacterAt: entireGlyphRange.location + entireGlyphRange.length)
//        if let startLinePosition = startLinePosition, let endLinePosition = endLinePosition {
//            for lineNumber in startLinePosition.lineNumber ... endLinePosition.lineNumber {
//                let lineLocation = textStorage.locationOfLine(withLineNumber: lineNumber)
//                let approach = lineHeightComputationApproach(forLineAt: lineLocation)
//                let isHighlightedLine = shouldHighlightLineNumber(lineNumber, inRangeOfSelectedLines: highlightedRange)
//                if isHighlightedLine, let lineRect = frameOfLine(atLocation: lineLocation, in: rect, using: approach) {
//                    drawHighlightedLineBackground(in: lineRect)
//                    if showLineNumbers {
//                        let lineNumberRect = CGRect(x: 0, y: lineRect.minY, width: gutterWidth, height: lineRect.height)
//                        drawHighlightedLineNumberBackground(in: lineNumberRect)
//                    }
//                }
//                if showLineNumbers, let lineNumberRect = frameOfLineNumberInLine(atLocation: lineLocation, in: rect, using: approach) {
//                    drawLineNumber(lineNumber, in: lineNumberRect, isHighlighted: isHighlightedLine)
//                }
//            }
//        }
//    }
//
//    private func frameOfLineNumberInLine(atLocation lineLocation: Int, in rect: CGRect, using approach: LineHeightComputationApproach) -> CGRect? {
//        guard let layoutManager = layoutManager else {
//            return nil
//        }
//        let bounds: CGRect
//        switch approach {
//        case .extraLine:
//            bounds = layoutManager.extraLineFragmentRect
//        case .lineBreak:
//            let lineHeight = font?.lineHeight ?? 0
//            let preferredGlyphRect = layoutManager.lineFragmentRect(forGlyphAt: lineLocation, effectiveRange: nil)
//            bounds = CGRect(x: preferredGlyphRect.minX, y: preferredGlyphRect.minY, width: preferredGlyphRect.width, height: lineHeight)
//        case .default:
//            bounds = layoutManager.lineFragmentRect(forGlyphAt: lineLocation, effectiveRange: nil)
//        }
//        return CGRect(x: 0, y: bounds.minY + textContainerInset.top, width: gutterWidth, height: bounds.height)
//    }
//
//    private func frameOfLine(atLocation lineLocation: Int, in rect: CGRect, using approach: LineHeightComputationApproach) -> CGRect? {
//        guard let textStorage = textStorage, let textContainer = textContainer, let layoutManager = layoutManager else {
//            return nil
//        }
//        switch approach {
//        case .extraLine:
//            let bounds = layoutManager.extraLineFragmentRect
//            return CGRect(x: gutterWidth, y: bounds.minY + textContainerInset.top, width: rect.width - gutterWidth, height: bounds.height)
//        case .lineBreak:
//            let lineHeight = font?.lineHeight ?? 0
//            let preferredGlyphRect = layoutManager.lineFragmentRect(forGlyphAt: lineLocation, effectiveRange: nil)
//            let bounds = CGRect(x: preferredGlyphRect.minX, y: preferredGlyphRect.minY, width: preferredGlyphRect.width, height: lineHeight)
//            return CGRect(x: gutterWidth, y: bounds.minY + textContainerInset.top, width: rect.width - gutterWidth, height: bounds.height)
//        case .default:
//            if let linePosition = textStorage.positionOfLine(containingCharacterAt: lineLocation) {
//                let entireGlyphRange = NSRange(location: lineLocation, length: linePosition.length)
//                let bounds = layoutManager.boundingRect(forGlyphRange: entireGlyphRange, in: textContainer)
//                return CGRect(x: gutterWidth, y: bounds.minY + textContainerInset.top, width: rect.width - gutterWidth, height: bounds.height)
//            } else {
//                return nil
//            }
//        }
//    }
//
//    private func drawHighlightedLineBackground(in rect: CGRect) {
//        let context = UIGraphicsGetCurrentContext()
//        context?.saveGState()
//        context?.setFillColor(theme.gutterBackgroundColorOnSelectedLine.cgColor)
//        context?.fill(rect)
//        context?.restoreGState()
//    }
//
//    private func drawHighlightedLineNumberBackground(in rect: CGRect) {
//        let context = UIGraphicsGetCurrentContext()
//        context?.saveGState()
//        context?.setFillColor(theme.gutterBackgroundColorOnSelectedLine.cgColor)
//        context?.fill(rect)
//        context?.restoreGState()
//    }

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

//    private func shouldHighlightLineNumber(_ lineNumber: Int, inRangeOfSelectedLines selectedLineRange: NSRange?) -> Bool {
//        if let selectedLineRange = selectedLineRange {
//            return lineNumber >= selectedLineRange.location && lineNumber <= selectedLineRange.location + selectedLineRange.length
//        } else {
//            return false
//        }
//    }
//
//    private func getRangeOfSelectedLineNumbers(selectedRange: NSRange) -> NSRange? {
//        guard highlightSelectedLine else {
//            return nil
//        }
//        guard let startLinePosition = delegate?.editorGutterController(self, positionOfCharacterAt: selectedRange.location) else {
//            return nil
//        }
//        let endLocation = selectedRange.location + selectedRange.length
//        if selectedRange.length > 0, let endLinePosition = delegate?.editorGutterController(self, positionOfCharacterAt: endLocation) {
//            let lineNumberLength = endLinePosition.lineNumber - startLinePosition.lineNumber
//            return NSRange(location: startLinePosition.lineNumber, length: lineNumberLength)
//        } else {
//            return NSRange(location: startLinePosition.lineNumber, length: 0)
//        }
//    }
//
//    private func height(of text: NSString) -> CGFloat {
//        let attributes: [NSAttributedString.Key: Any] = [.font: theme.lineNumberFont]
//        let textSize = text.size(withAttributes: attributes)
//        return textSize.height
//    }
//
//    private func isEmptyLine(at range: NSRange) -> Bool {
//        let str = delegate?.editorGutterController(self, substringIn: range)
//        return str == nil || str == Symbol.lineFeed
//    }
//
//    private func lineHeightComputationApproach(forLineAt lineLocation: Int) -> LineHeightComputationApproach {
//        guard let layoutManager = layoutManager else {
//            return .default
//        }
//        let firstGlyphRange = NSRange(location: lineLocation, length: 1)
//        let preferredGlyphRect = layoutManager.lineFragmentRect(forGlyphAt: lineLocation, effectiveRange: nil)
//        if preferredGlyphRect == .zero {
//            // It's the extra blank line at the end of the document.
//            return .extraLine
//        } else if delegate?.editorGutterController(self, substringIn: firstGlyphRange) == Symbol.lineFeed {
//            // The first character is a line break. This happens on lines that aren't the least line but contains only a line break.
//            return .lineBreak
//        } else {
//            // Handle any other line.
//            return .default
//        }
//    }
}
