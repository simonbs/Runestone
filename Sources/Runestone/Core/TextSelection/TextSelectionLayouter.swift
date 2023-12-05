#if os(macOS)
import Combine
import Foundation

final class TextSelectionLayouter {
    let backgroundColor = CurrentValueSubject<MultiPlatformColor, Never>(.label.withAlphaComponent(0.2))

    private let textSelectionRectFactory: TextSelectionRectFactory
    private let containerView: CurrentValueSubject<TextView, Never>
    private let viewQueue = ReusableViewQueue<String, LineSelectionView>()
    private var cancellables = Set<AnyCancellable>()

    init(
        textSelectionRectFactory: TextSelectionRectFactory,
        containerView: CurrentValueSubject<TextView, Never>,
        viewport: CurrentValueSubject<CGRect, Never>,
        selectedRange: CurrentValueSubject<NSRange, Never>
    ) {
        self.textSelectionRectFactory = textSelectionRectFactory
        self.containerView = containerView
        setupBackgroundColorObserver()
        setupSelectedRangeObserver(viewport: viewport, selectedRange: selectedRange)
    }
}

private extension TextSelectionLayouter {
    private func setupBackgroundColorObserver() {
        backgroundColor.sink { [weak self] backgroundColor in
            guard let self else {
                return
            }
            for (_, view) in self.viewQueue.visibleViews {
                view.backgroundColor = backgroundColor
            }
        }.store(in: &cancellables)
    }

    private func setupSelectedRangeObserver(viewport: CurrentValueSubject<CGRect, Never>, selectedRange: CurrentValueSubject<NSRange, Never>) {
        Publishers.CombineLatest(
            viewport.removeDuplicates(by: { $0.size == $1.size }),
            selectedRange.map { $0.nonNegativeLength }
        ).sink { [weak self] _, selectedRange in
            guard let self else {
                return
            }
            if selectedRange.length > 0 {
                let selectionRects = self.textSelectionRectFactory.selectionRects(in: selectedRange)
                self.addViews(for: selectionRects)
            } else {
                self.removeAllViews()
            }
        }.store(in: &cancellables)
    }

    private func removeAllViews() {
        for (_, view) in viewQueue.visibleViews {
            view.removeFromSuperview()
        }
        let keys = Set(viewQueue.visibleViews.keys)
        viewQueue.enqueueViews(withKeys: keys)
    }

    private func addViews(for selectionRects: [TextSelectionRect]) {
        var appearedViewKeys = Set<String>()
        for (idx, selectionRect) in selectionRects.enumerated() {
            let key = String(describing: idx)
            let view = viewQueue.dequeueView(forKey: key)
            view.frame = selectionRect.rect
            view.backgroundColor = backgroundColor.value
            view.layer?.zPosition = 500
            containerView.value.addSubview(view)
            appearedViewKeys.insert(key)
        }
        let disappearedViewKeys = Set(viewQueue.visibleViews.keys).subtracting(appearedViewKeys)
        viewQueue.enqueueViews(withKeys: disappearedViewKeys)
    }
}
#endif
