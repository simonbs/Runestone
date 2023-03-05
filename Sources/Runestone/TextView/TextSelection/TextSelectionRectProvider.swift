import Combine
import CoreGraphics
import Foundation

final class TextSelectionRectProvider {
    private let lineManager: LineManager
    private let contentAreaProvider: ContentAreaProvider
    private let caretRectProvider: CaretRectProvider
    private let lineHeightMultiplier: CurrentValueSubject<CGFloat, Never>

    init(
        lineManager: LineManager,
        contentAreaProvider: ContentAreaProvider,
        caretRectProvider: CaretRectProvider,
        lineHeightMultiplier: CurrentValueSubject<CGFloat, Never>
    ) {
        self.lineManager = lineManager
        self.contentAreaProvider = contentAreaProvider
        self.caretRectProvider = caretRectProvider
        self.lineHeightMultiplier = lineHeightMultiplier
    }

    func selectionRects(in range: NSRange) -> [TextSelectionRect] {
        guard range.length > 0 else {
            return []
        }
        guard let endLine = lineManager.line(containingCharacterAt: range.upperBound) else {
            return []
        }
        let contentArea = contentAreaProvider.contentArea
        let selectsLineEnding = range.upperBound == endLine.location
        let adjustedRange = NSRange(location: range.location, length: selectsLineEnding ? range.length - 1 : range.length)
        let startCaretRect = caretRectProvider.caretRect(at: adjustedRange.lowerBound, allowMovingCaretToNextLineFragment: true)
        let endCaretRect = caretRectProvider.caretRect(at: adjustedRange.upperBound, allowMovingCaretToNextLineFragment: false)
        if startCaretRect.minY == endCaretRect.minY && startCaretRect.maxY == endCaretRect.maxY {
            // Selecting text in the same line fragment.
            let width = selectsLineEnding ? contentArea.width - (startCaretRect.minX - contentArea.minX) : endCaretRect.maxX - startCaretRect.maxX
            let scaledHeight = startCaretRect.height * lineHeightMultiplier.value
            let offsetY = startCaretRect.minY - (scaledHeight - startCaretRect.height) / 2
            let rect = CGRect(x: startCaretRect.minX, y: offsetY, width: width, height: scaledHeight)
            let selectionRect = TextSelectionRect(rect: rect, writingDirection: .natural, containsStart: true, containsEnd: true)
            return [selectionRect]
        } else {
            // Selecting text across line fragments and possibly across lines.
            let startWidth = contentArea.width - (startCaretRect.minX - contentArea.minX)
            let startScaledHeight = startCaretRect.height * lineHeightMultiplier.value
            let startOffsetY = startCaretRect.minY - (startScaledHeight - startCaretRect.height) / 2
            let startRect = CGRect(x: startCaretRect.minX, y: startOffsetY, width: startWidth, height: startScaledHeight)
            let endWidth = selectsLineEnding ? contentArea.width : endCaretRect.minX - contentArea.minX
            let endScaledHeight = endCaretRect.height * lineHeightMultiplier.value
            let endOffsetY = endCaretRect.minY - (endScaledHeight - endCaretRect.height) / 2
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
