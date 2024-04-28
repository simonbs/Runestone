import CoreGraphics
import Foundation

struct TextSelectionRectProvider<LineManagerType: LineManaging> {
    typealias State = LineHeightMultiplierReadable & TextContainerInsetReadable

    private let state: State
    private let characterBoundsProvider: CharacterBoundsProviding
    private let lineManager: LineManagerType
    private let contentSizeService: ContentSizeService<LineManagerType>
    private var contentArea: CGRect {
        let textContainerInset = state.textContainerInset
        let contentSize = contentSizeService.contentSize
        let width = contentSize.width - textContainerInset.left - textContainerInset.right
        let height = contentSize.height - textContainerInset.top - textContainerInset.bottom
        return CGRect(x: textContainerInset.left, y: textContainerInset.right, width: width, height: height)
    }

    init(
        state: State,
        characterBoundsProvider: CharacterBoundsProviding,
        lineManager: LineManagerType,
        contentSizeService: ContentSizeService<LineManagerType>
    ) {
        self.state = state
        self.characterBoundsProvider = characterBoundsProvider
        self.lineManager = lineManager
        self.contentSizeService = contentSizeService
    }

    func textSelectionRects(in range: NSRange) -> [TextSelectionRect] {
        guard range.length > 0 else {
            return []
        }
        guard let endLine = lineManager.line(containingCharacterAt: range.upperBound) else {
            return []
        }
        let adjustedRange = NSRange(location: range.location, length: range.length - 1)
        let selectsLineEnding = range.upperBound == endLine.location
        guard let lowerRect = characterBoundsProvider.boundsOfCharacter(atLocation: adjustedRange.lowerBound) else {
            return []
        }
        guard let upperRect = characterBoundsProvider.boundsOfCharacter(atLocation: adjustedRange.upperBound) else {
            return []
        }
        if lowerRect.minY == upperRect.minY && lowerRect.maxY == upperRect.maxY {
            return rectsInSingleLineFragment(from: lowerRect, to: upperRect, selectsLineEnding: selectsLineEnding)
        } else {
            return rectsInMultipleLineFragments(from: lowerRect, to: upperRect, selectsLineEnding: selectsLineEnding)
        }
    }
}

private extension TextSelectionRectProvider {
    private func rectsInSingleLineFragment(
        from lowerRect: CGRect,
        to upperRect: CGRect,
        selectsLineEnding: Bool
    ) -> [TextSelectionRect] {
        let width = if selectsLineEnding {
            contentArea.width - (lowerRect.minX - contentArea.minX)
        } else {
            upperRect.maxX - lowerRect.minX
        }
        let scaledHeight = lowerRect.height * state.lineHeightMultiplier
        let offsetY = lowerRect.minY - (scaledHeight - lowerRect.height) / 2
        let rect = CGRect(x: lowerRect.minX, y: offsetY, width: width, height: scaledHeight)
        return [TextSelectionRect(rect: rect, writingDirection: .natural, containsStart: true, containsEnd: true)]
    }

    private func rectsInMultipleLineFragments(
        from lowerRect: CGRect,
        to upperRect: CGRect,
        selectsLineEnding: Bool
    ) -> [TextSelectionRect] {
        let startWidth = contentArea.width - (lowerRect.minX - contentArea.minX)
        let startScaledHeight = lowerRect.height * state.lineHeightMultiplier
        let startOffsetY = lowerRect.minY - (startScaledHeight - lowerRect.height) / 2
        let startRect = CGRect(x: lowerRect.minX, y: startOffsetY, width: startWidth, height: startScaledHeight)
        let endWidth = if selectsLineEnding {
            contentArea.width
        } else {
            upperRect.maxX - contentArea.minX
        }
        let endScaledHeight = upperRect.height * state.lineHeightMultiplier
        let endOffsetY = upperRect.minY - (endScaledHeight - upperRect.height) / 2
        let endRect = CGRect(x: contentArea.minX, y: endOffsetY, width: endWidth, height: endScaledHeight)
        let middleHeight = endRect.minY - startRect.maxY
        let middleRect = CGRect(x: contentArea.minX, y: startRect.maxY, width: contentArea.width, height: middleHeight)
        return [
            TextSelectionRect(rect: startRect, writingDirection: .natural, containsStart: true, containsEnd: false),
            TextSelectionRect(rect: middleRect, writingDirection: .natural, containsStart: false, containsEnd: false),
            TextSelectionRect(rect: endRect, writingDirection: .natural, containsStart: false, containsEnd: true)
        ]
    }
}
