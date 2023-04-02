import Combine
import CoreGraphics

final class TextViewNeedsLayoutObserver {
    private let textView: CurrentValueSubject<WeakBox<TextView>, Never>
    private let stringView: CurrentValueSubject<StringView, Never>
    private let viewport: CurrentValueSubject<CGRect, Never>
    private var cancellables: Set<AnyCancellable> = []

    init(
        textView: CurrentValueSubject<WeakBox<TextView>, Never>,
        stringView: CurrentValueSubject<StringView, Never>,
        viewport: CurrentValueSubject<CGRect, Never>
    ) {
        self.textView = textView
        self.stringView = stringView
        self.viewport = viewport
        setupObserver()
    }
}

private extension TextViewNeedsLayoutObserver {
    private func setupObserver() {
        Publishers.CombineLatest(stringView, viewport.removeDuplicates()).sink { [weak self] _ in
            self?.textView.value.value?.setNeedsLayout()
        }.store(in: &cancellables)
    }
}
