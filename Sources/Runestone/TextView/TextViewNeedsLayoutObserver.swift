import Combine
import CoreGraphics

final class TextViewNeedsLayoutObserver {
    private unowned let textView: TextView
    private let stringView: CurrentValueSubject<StringView, Never>
    private let viewport: CurrentValueSubject<CGRect, Never>
    private var cancellables: Set<AnyCancellable> = []

    init(
        textView: TextView,
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
            self?.textView.setNeedsLayout()
        }.store(in: &cancellables)
    }
}
