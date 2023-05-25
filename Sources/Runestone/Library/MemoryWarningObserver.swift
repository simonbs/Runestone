#if os(iOS)
import UIKit

protocol LowMemoryHandling {
    func handleLowMemory()
}

final class MemoryWarningObserver {
    private let handlers: [LowMemoryHandling]

    init(handlers: [LowMemoryHandling]) {
        self.handlers = handlers
        subscribeToMemoryWarningNotification()
    }
}

private extension MemoryWarningObserver {
    private func subscribeToMemoryWarningNotification() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didReceiveMemoryWarningNotification),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func didReceiveMemoryWarningNotification() {
        for handler in handlers {
            handler.handleLowMemory()
        }
    }
}
#endif
