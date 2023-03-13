import Combine
import CoreGraphics
import Foundation

final class TextSelectionRectFactory {
    private let caret: Caret
    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let contentArea: CurrentValueSubject<CGRect, Never>
    private let lineHeightMultiplier: CurrentValueSubject<CGFloat, Never>

    init(
        caret: Caret,
        lineManager: CurrentValueSubject<LineManager, Never>,
        contentArea: CurrentValueSubject<CGRect, Never>,
        lineHeightMultiplier: CurrentValueSubject<CGFloat, Never>
    ) {
        self.caret = caret
        self.lineManager = lineManager
        self.contentArea = contentArea
        self.lineHeightMultiplier = lineHeightMultiplier
    }

    func selectionRects(in range: NSRange) -> [TextSelectionRect] {
        guard range.length > 0 else {
            return []
        }
        guard let endLine = lineManager.value.line(containingCharacterAt: range.upperBound) else {
            return []
        }
        let contentArea = contentArea.value
        let selectsLineEnding = range.upperBound == endLine.location
        let adjustedRange = NSRange(location: range.location, length: selectsLineEnding ? range.length - 1 : range.length)
        let startCaretFrame = caret.frame(at: adjustedRange.lowerBound, allowMovingCaretToNextLineFragment: true)
        let endCaretFrame = caret.frame(at: adjustedRange.upperBound, allowMovingCaretToNextLineFragment: false)
        if startCaretFrame.minY == endCaretFrame.minY && startCaretFrame.maxY == endCaretFrame.maxY {
            // Selecting text in the same line fragment.
            let width = selectsLineEnding ? contentArea.width - (startCaretFrame.minX - contentArea.minX) : endCaretFrame.maxX - startCaretFrame.maxX
            let scaledHeight = startCaretFrame.height * lineHeightMultiplier.value
            let offsetY = startCaretFrame.minY - (scaledHeight - startCaretFrame.height) / 2
            let rect = CGRect(x: startCaretFrame.minX, y: offsetY, width: width, height: scaledHeight)
            let selectionRect = TextSelectionRect(rect: rect, writingDirection: .natural, containsStart: true, containsEnd: true)
            return [selectionRect]
        } else {
            // Selecting text across line fragments and possibly across lines.
            let startWidth = contentArea.width - (startCaretFrame.minX - contentArea.minX)
            let startScaledHeight = startCaretFrame.height * lineHeightMultiplier.value
            let startOffsetY = startCaretFrame.minY - (startScaledHeight - startCaretFrame.height) / 2
            let startRect = CGRect(x: startCaretFrame.minX, y: startOffsetY, width: startWidth, height: startScaledHeight)
            let endWidth = selectsLineEnding ? contentArea.width : endCaretFrame.minX - contentArea.minX
            let endScaledHeight = endCaretFrame.height * lineHeightMultiplier.value
            let endOffsetY = endCaretFrame.minY - (endScaledHeight - endCaretFrame.height) / 2
            let endRect = CGRect(x: contentArea.minX, y: endOffsetY, width: endWidth, height: endScaledHeight)
            let middleHeight = endRect.minY - startRect.maxY
            let middleRect = CGRect(x: contentArea.minX, y: startRect.maxY, width: contentArea.width, height: middleHeight)
            let startSelectionRect = TextSelectionRect(rect: startRect, writingDirection: .natural, containsStart: true, containsEnd: false)
            let middleSelectionRect = TextSelectionRect(rect: middleRect, writingDirection: .natural, containsStart: false, containsEnd: false)
            let endSelectionRect = TextSelectionRect(rect: endRect, writingDirection: .natural, containsStart: false, containsEnd: true)
            return [startSelectionRect, middleSelectionRect, endSelectionRect]
        }
    }
}
