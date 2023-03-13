import Combine
import Foundation

final class LineSelectionLayouter {
    let lineSelectionDisplayType = CurrentValueSubject<LineSelectionDisplayType, Never>(.disabled)

    private let caret: Caret
    private let lineSelectionView = MultiPlatformView()
    private var cancellables: Set<AnyCancellable> = []

    init(
        caret: Caret,
        selectedRange: CurrentValueSubject<NSRange, Never>,
        lineManager: CurrentValueSubject<LineManager, Never>,
        viewport: CurrentValueSubject<CGRect, Never>,
        textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>,
        lineHeightMultiplier: CurrentValueSubject<CGFloat, Never>,
        backgroundColor: CurrentValueSubject<MultiPlatformColor, Never>,
        containerView: MultiPlatformView
    ) {
        self.caret = caret
        lineSelectionView.layerIfLoaded?.zPosition = -1000
        containerView.addSubview(lineSelectionView)
        setupBackgroundColorSubscriber(backgroundColor: backgroundColor)
        setupHiddenSubscriber(
            lineSelectionDisplayType: lineSelectionDisplayType,
            selectedRange: selectedRange
        )
        setupFrameSubscriber(
            lineSelectionDisplayType: lineSelectionDisplayType,
            selectedRange: selectedRange,
            lineManager: lineManager,
            viewport: viewport,
            textContainerInset: textContainerInset,
            lineHeightMultiplier: lineHeightMultiplier
        )
    }
}

private extension LineSelectionLayouter {
    private func setupBackgroundColorSubscriber(backgroundColor: CurrentValueSubject<MultiPlatformColor, Never>) {
        backgroundColor.sink { [weak self] color in
            self?.lineSelectionView.backgroundColor = color
        }.store(in: &cancellables)
    }

    private func setupHiddenSubscriber(
        lineSelectionDisplayType: CurrentValueSubject<LineSelectionDisplayType, Never>,
        selectedRange: CurrentValueSubject<NSRange, Never>
    ) {
        Publishers.CombineLatest(lineSelectionDisplayType, selectedRange).sink { [weak self] lineSelectionDisplayType, selectedRange in
            self?.lineSelectionView.isHidden = lineSelectionDisplayType == .disabled || selectedRange.length > 0
        }.store(in: &cancellables)
    }

    private func setupFrameSubscriber(
        lineSelectionDisplayType: CurrentValueSubject<LineSelectionDisplayType, Never>,
        selectedRange: CurrentValueSubject<NSRange, Never>,
        lineManager: CurrentValueSubject<LineManager, Never>,
        viewport: CurrentValueSubject<CGRect, Never>,
        textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>,
        lineHeightMultiplier: CurrentValueSubject<CGFloat, Never>
    ) {
        Publishers.CombineLatest(
            Publishers.CombineLatest4(caret.frame, lineSelectionDisplayType, selectedRange, lineManager),
            Publishers.CombineLatest3(viewport, textContainerInset, lineHeightMultiplier)
        ).sink { [weak self] tupleA, tupleB in
            guard let self else {
                return
            }
            let (_, lineSelectionDisplayType, selectedRange, lineManager) = tupleA
            let (viewport, textContainerInset, lineHeightMultiplier) = tupleB
            let rectFactory = LineSelectionRectFactory(
                viewport: viewport,
                caret: self.caret,
                lineManager: lineManager,
                lineSelectionDisplayType: lineSelectionDisplayType,
                textContainerInset: textContainerInset,
                lineHeightMultiplier: lineHeightMultiplier,
                selectedRange: selectedRange
            )
            if let frame = rectFactory.rect {
                self.lineSelectionView.frame = frame
            }
        }.store(in: &cancellables)
    }
}
