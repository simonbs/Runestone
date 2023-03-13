#if os(macOS)
import AppKit
import Combine

final class KeyWindowObserver {
    let isKeyWindow = CurrentValueSubject<Bool, Never>(false)

    private weak var referenceView: NSView?
    private var cancellables = Set<AnyCancellable>()

    init(referenceView: NSView) {
        self.referenceView = referenceView
        NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification).sink { [weak self] _ in
            self?.isKeyWindow.value = self?.referenceView?.window?.isKeyWindow ?? false
        }.store(in: &cancellables)
    }
}
#endif
