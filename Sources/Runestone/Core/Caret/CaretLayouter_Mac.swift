#if os(macOS)
import Combine
import Foundation

final class CaretLayouter {
    var color: MultiPlatformColor {
        get {
            caretView.color
        }
        set {
            caretView.color = newValue
        }
    }

    private let caretView = CaretView()
    private var cancellabels: Set<AnyCancellable> = []

    init(
        caret: Caret,
        containerView: CurrentValueSubject<WeakBox<TextView>, Never>,
        selectedRange: AnyPublisher<NSRange, Never>,
        showCaret: AnyPublisher<Bool, Never>
    ) {
        caretView.layer?.zPosition = 1000
        caretView.isHidden = true
        containerView.value.value?.addSubview(caretView)
        selectedRange.removeDuplicates().sink { [weak self] selectedRange in
            self?.caretView.delayBlink()
        }.store(in: &cancellabels)
        caret.frame.sink { [weak self] frame in
            self?.caretView.frame = frame
        }.store(in: &cancellabels)
        showCaret.removeDuplicates().sink { [weak self] showCaret in
            if showCaret {
                self?.caretView.isHidden = false
                self?.caretView.isBlinkingEnabled = true
                self?.caretView.delayBlink()
            } else {
                self?.caretView.isHidden = true
                self?.caretView.isBlinkingEnabled = false
            }
        }.store(in: &cancellabels)
    }
}
#endif
