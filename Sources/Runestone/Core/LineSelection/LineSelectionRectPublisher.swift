import _RunestoneMultiPlatform
import Combine
import CoreGraphics
import Foundation

final class LineSelectionRectPublisher<LineManagerType: LineManaging> {
    let rect: AnyPublisher<CGRect?, Never>

    private let _rect = PassthroughSubject<CGRect?, Never>()
    private var cancellables: Set<AnyCancellable> = []

    init(
        lineSelectionDisplayType: CurrentValueSubject<LineSelectionDisplayType, Never>,
        selectedRange: CurrentValueSubject<NSRange, Never>,
        lineManager: LineManagerType,
        viewport: CurrentValueSubject<CGRect, Never>,
        textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>,
        lineHeightMultiplier: CurrentValueSubject<CGFloat, Never>
    ) {
        self.rect = _rect.eraseToAnyPublisher()
        Publishers.CombineLatest(
            Publishers.CombineLatest(lineSelectionDisplayType, selectedRange),
            Publishers.CombineLatest3(viewport, textContainerInset, lineHeightMultiplier)
        ).sink { [weak self] tupleA, tupleB in
            guard let self else {
                return
            }
            let (lineSelectionDisplayType, selectedRange) = tupleA
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
        lineManager: LineManagerType,
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
        lineManager: LineManagerType,
        viewport: CGRect,
        textContainerInset: MultiPlatformEdgeInsets
    ) -> CGRect? {
        guard let (firstLine, lastLine) = lineManager.firstAndLastLine(in: selectedRange) else {
            return nil
        }
        let yPosition = firstLine.yPosition
        let height = (lastLine.yPosition + lastLine.height) - yPosition
        return CGRect(x: viewport.minX, y: textContainerInset.top + yPosition, width: viewport.width, height: height)
    }

    private func getLineFragmentSelectionRect(
        selectedRange: NSRange,
        lineManager: LineManagerType,
        viewport: CGRect,
        textContainerInset: MultiPlatformEdgeInsets
    ) -> CGRect? {
        guard let (firstLine, lastLine) = lineManager.firstAndLastLine(in: selectedRange) else {
            return nil
        }
        let lineLocalLowerBound = selectedRange.lowerBound - firstLine.location
        let lineLocalUpperBound = selectedRange.upperBound - lastLine.location
        let startLineFragment = firstLine.lineFragment(containingLocation: lineLocalLowerBound)
        let endLineFragment = lastLine.lineFragment(containingLocation: lineLocalUpperBound)
        let origin = CGPoint(x: viewport.minX, y: textContainerInset.top + startLineFragment.yPosition)
        let height = endLineFragment.yPosition + endLineFragment.scaledSize.height - origin.y
        let size = CGSize(width: viewport.width, height: height)
        return CGRect(origin: origin, size: size)
    }
}
