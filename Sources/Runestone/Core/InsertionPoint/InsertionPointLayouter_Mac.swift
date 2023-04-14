#if os(macOS)
import Combine
import Foundation

final class InsertionPointLayouter {
    private let view: InsertionPointView
    private var cancellabels: Set<AnyCancellable> = []

    init(
        renderer: InsertionPointRenderer,
        frame: AnyPublisher<CGRect, Never>,
        containerView: CurrentValueSubject<WeakBox<TextView>, Never>,
        selectedRange: AnyPublisher<NSRange, Never>,
        showInsertionPoint: AnyPublisher<Bool, Never>
    ) {
        view = InsertionPointView(selectedRange: selectedRange, renderer: renderer)
        view.layer?.zPosition = 1000
        view.isHidden = true
        selectedRange.removeDuplicates().sink { [weak self] _ in
            self?.view.delayBlink()
        }.store(in: &cancellabels)
        showInsertionPoint.removeDuplicates().sink { [weak self] showCaret in
            if showCaret {
                self?.view.isHidden = false
                self?.view.isBlinkingEnabled = true
                self?.view.delayBlink()
            } else {
                self?.view.isHidden = true
                self?.view.isBlinkingEnabled = false
            }
        }.store(in: &cancellabels)
        containerView.sink { [weak self] box in
            if let self {
                self.view.removeFromSuperview()
                box.value?.addSubview(self.view)
            }
        }.store(in: &cancellabels)
        frame.sink { [weak self] frame in
            self?.view.frame = frame
        }.store(in: &cancellabels)
    }
}
#endif
