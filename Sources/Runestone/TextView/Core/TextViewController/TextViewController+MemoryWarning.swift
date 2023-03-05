#if os(iOS)
import UIKit

extension TextViewController {
    func subscribeToMemoryWarningNotification() {
        let memoryWarningNotificationName = UIApplication.didReceiveMemoryWarningNotification
        NotificationCenter.default.addObserver(self, selector: #selector(clearMemory), name: memoryWarningNotificationName, object: nil)
    }
}

private extension TextViewController {
    @objc private func clearMemory() {
        lineControllerStorage.removeAllLineControllers(exceptLinesWithID: lineFragmentLayouter.visibleLineIDs)
    }
}
#endif
