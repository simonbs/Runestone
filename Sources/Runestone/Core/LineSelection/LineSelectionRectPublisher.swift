import Combine
import CoreGraphics
import Foundation

final class LineSelectionRectPublisher {
    let rect: AnyPublisher<CGRect?, Never>

    private let _rect = PassthroughSubject<CGRect?, Never>()
    private let lineControllerStorage: LineControllerStorage
    private var cancellables: Set<AnyCancellable> = []

    init(
        lineSelectionDisplayType: CurrentValueSubject<LineSelectionDisplayType, Never>,
        selectedRange: CurrentValueSubject<NSRange, Never>,
        lineManager: CurrentValueSubject<LineManager, Never>,
        lineControllerStorage: LineControllerStorage,
        viewport: CurrentValueSubject<CGRect, Never>,
        textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>,
        lineHeightMultiplier: CurrentValueSubject<CGFloat, Never>
    ) {
        self.rect = _rect.eraseToAnyPublisher()
        self.lineControllerStorage = lineControllerStorage
        Publishers.CombineLatest(
            Publishers.CombineLatest3(lineSelectionDisplayType, selectedRange, lineManager),
            Publishers.CombineLatest3(viewport, textContainerInset, lineHeightMultiplier)
        ).sink { [weak self] tupleA, tupleB in
            guard let self else {
                return
            }
            let (lineSelectionDisplayType, selectedRange, lineManager) = tupleA
            let (viewport, textContainerInset, _) = tupleB
            let rect = self.getRect(
                lineSelectionDisplayType: lineSelectionDisplayType,
                selectedRange: selectedRange,
                lineManager: lineManager,
                viewport: viewport,
                textContainerInset: textContainerInset
            )
            self._rect.send(rect)
        }.store(in: &cancellables)
    }
}

private extension LineSelectionRectPublisher {
    private func getRect(
        lineSelectionDisplayType: LineSelectionDisplayType,
        selectedRange: NSRange,
        lineManager: LineManager,
        viewport: CGRect,
        textContainerInset: MultiPlatformEdgeInsets
    ) -> CGRect? {
        switch lineSelectionDisplayType {
        case .line:
            return getEntireLineSelectionRect(
                selectedRange: selectedRange,
                lineManager: lineManager,
                viewport: viewport,
                textContainerInset: textContainerInset
            )
        case .lineFragment:
            return getLineFragmentSelectionRect(
                selectedRange: selectedRange,
                lineManager: lineManager,
                viewport: viewport,
                textContainerInset: textContainerInset
            )
        case .disabled:
            return nil
        }
    }

    private func getEntireLineSelectionRect(
        selectedRange: NSRange,
        lineManager: LineManager,
        viewport: CGRect,
        textContainerInset: MultiPlatformEdgeInsets
    ) -> CGRect? {
        guard let (startLine, endLine) = lineManager.startAndEndLine(in: selectedRange) else {
            return nil
        }
        let yPosition = startLine.yPosition
        let height = (endLine.yPosition + endLine.data.lineHeight) - yPosition
        return CGRect(x: viewport.minX, y: textContainerInset.top + yPosition, width: viewport.width, height: height)
    }

    private func getLineFragmentSelectionRect(
        selectedRange: NSRange,
        lineManager: LineManager,
        viewport: CGRect,
        textContainerInset: MultiPlatformEdgeInsets
    ) -> CGRect? {
        guard let (startLine, endLine) = lineManager.startAndEndLine(in: selectedRange) else {
            return nil
        }
        let lineLocalLowerBound = selectedRange.lowerBound - startLine.location
        let lineLocalUpperBound = selectedRange.upperBound - endLine.location
        let startLineController = lineControllerStorage.getOrCreateLineController(for: startLine)
        let endLineController = lineControllerStorage.getOrCreateLineController(for: endLine)
        guard let startLineFragmentNode = startLineController.lineFragmentNode(containingCharacterAt: lineLocalLowerBound) else {
            return nil
        }
        guard let endLineFragmentNode = endLineController.lineFragmentNode(containingCharacterAt: lineLocalUpperBound) else {
            return nil
        }
        guard let startLineFragment = startLineFragmentNode.data.lineFragment, let endLineFragment = endLineFragmentNode.data.lineFragment else {
            return nil
        }
        let origin = CGPoint(x: viewport.minX, y: textContainerInset.top + startLineFragment.yPosition)
        let size = CGSize(width: viewport.width, height: endLineFragment.yPosition + endLineFragment.scaledSize.height - origin.y)
        return CGRect(origin: origin, size: size)
    }
}
