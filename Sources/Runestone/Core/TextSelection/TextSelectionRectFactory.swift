import Combine
import CoreGraphics
import Foundation

final class TextSelectionRectFactory<StringViewType: StringView, LineManagerType: LineManaging> {
    private let characterBoundsProvider: CharacterBoundsProvider<StringViewType, LineManagerType>
    private let lineManager: LineManagerType
    private let lineHeightMultiplier: CurrentValueSubject<CGFloat, Never>
    private var contentArea: CGRect = .zero
    private var cancellables: Set<AnyCancellable> = []

    init(
        characterBoundsProvider: CharacterBoundsProvider<StringViewType, LineManagerType>,
        lineManager: LineManagerType,
        contentArea: AnyPublisher<CGRect, Never>,
        lineHeightMultiplier: CurrentValueSubject<CGFloat, Never>
    ) {
        self.characterBoundsProvider = characterBoundsProvider
        self.lineManager = lineManager
        self.lineHeightMultiplier = lineHeightMultiplier
        contentArea.sink { [weak self] contentArea in
            self?.contentArea = contentArea
        }.store(in: &cancellables)
    }

    func selectionRects(in range: NSRange) -> [TextSelectionRect] {
        guard range.length > 0 else {
            return []
        }
        guard let endLine = lineManager.line(containingCharacterAt: range.upperBound) else {
            return []
        }
        let adjustedRange = NSRange(location: range.location, length: range.length - 1)
        let selectsLineEnding = range.upperBound == endLine.location
        guard let lowerRect = characterBoundsProvider.boundsOfCharacter(
            atLocation: adjustedRange.lowerBound
//            moveToToNextLineFragmentIfNeeded: false
        ) else {
            return []
        }
        guard let upperRect = characterBoundsProvider.boundsOfCharacter(
            atLocation: adjustedRange.upperBound
//            moveToToNextLineFragmentIfNeeded: false
        ) else {
            return []
        }
        if lowerRect.minY == upperRect.minY && lowerRect.maxY == upperRect.maxY {
            return createRectsInSingleLineFragment(from: lowerRect, to: upperRect, selectsLineEnding: selectsLineEnding)
        } else {
            return createRectsSpanningMultipleLineFragments(from: lowerRect, to: upperRect, selectsLineEnding: selectsLineEnding)
        }
    }
}

private extension TextSelectionRectFactory {
    private func createRectsInSingleLineFragment(from lowerRect: CGRect, to upperRect: CGRect, selectsLineEnding: Bool) -> [TextSelectionRect] {
        // Selecting text in the same line fragment.
        let width = selectsLineEnding ? contentArea.width - (lowerRect.minX - contentArea.minX) : upperRect.maxX - lowerRect.minX
        let scaledHeight = lowerRect.height * lineHeightMultiplier.value
        let offsetY = lowerRect.minY - (scaledHeight - lowerRect.height) / 2
        let rect = CGRect(x: lowerRect.minX, y: offsetY, width: width, height: scaledHeight)
        let selectionRect = TextSelectionRect(rect: rect, writingDirection: .natural, containsStart: true, containsEnd: true)
        return [selectionRect]
    }

    private func createRectsSpanningMultipleLineFragments(
        from lowerRect: CGRect,
        to upperRect: CGRect,
        selectsLineEnding: Bool
    ) -> [TextSelectionRect] {
        // Selecting text across line fragments and possibly across lines.
        let startWidth = contentArea.width - (lowerRect.minX - contentArea.minX)
        let startScaledHeight = lowerRect.height * lineHeightMultiplier.value
        let startOffsetY = lowerRect.minY - (startScaledHeight - lowerRect.height) / 2
        let startRect = CGRect(x: lowerRect.minX, y: startOffsetY, width: startWidth, height: startScaledHeight)
        let endWidth = selectsLineEnding ? contentArea.width : upperRect.maxX - contentArea.minX
        let endScaledHeight = upperRect.height * lineHeightMultiplier.value
        let endOffsetY = upperRect.minY - (endScaledHeight - upperRect.height) / 2
        let endRect = CGRect(x: contentArea.minX, y: endOffsetY, width: endWidth, height: endScaledHeight)
        let middleHeight = endRect.minY - startRect.maxY
        let middleRect = CGRect(x: contentArea.minX, y: startRect.maxY, width: contentArea.width, height: middleHeight)
        let startSelectionRect = TextSelectionRect(rect: startRect, writingDirection: .natural, containsStart: true, containsEnd: false)
        let middleSelectionRect = TextSelectionRect(rect: middleRect, writingDirection: .natural, containsStart: false, containsEnd: false)
        let endSelectionRect = TextSelectionRect(rect: endRect, writingDirection: .natural, containsStart: false, containsEnd: true)
        return [startSelectionRect, middleSelectionRect, endSelectionRect]
    }
}
