#if os(macOS)
import AppKit
import Combine

final class KeyWindowObserver_Mac: KeyWindowObserver {
    let isKeyWindow = CurrentValueSubject<Bool, Never>(false)

    private let referenceView: CurrentValueSubject<WeakBox<TextView>, Never>
    private var cancellables = Set<AnyCancellable>()

    init(referenceView: CurrentValueSubject<WeakBox<TextView>, Never>) {
        self.referenceView = referenceView
        NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification).sink { [weak self] _ in
            self?.isKeyWindow.value = self?.referenceView.value.value?.window?.isKeyWindow ?? false
        }.store(in: &cancellables)
    }
}
#endif
