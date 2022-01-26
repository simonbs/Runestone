import UIKit

protocol ReusableView {
    func prepareForReuse()
}

extension ReusableView {
    func prepareForReuse() {}
}

final class ViewReuseQueue<Key: Hashable, View: UIView & ReusableView> {
    private(set) var visibleViews: [Key: View] = [:]

    private var queuedViews: Set<View> = []

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearMemory),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func enqueueViews(withKeys keys: Set<Key>) {
        for key in keys {
            if let view = visibleViews.removeValue(forKey: key) {
                view.prepareForReuse()
                view.removeFromSuperview()
                queueViewIfNeeded(view)
            }
        }
    }

    func dequeueView(forKey key: Key) -> View {
        if let view = visibleViews[key] {
            return view
        } else if !queuedViews.isEmpty {
            let view = queuedViews.removeFirst()
            visibleViews[key] = view
            return view
        } else {
            let view = View()
            visibleViews[key] = view
            return view
        }
    }

    private func queueViewIfNeeded(_ view: View) {
        // There's no need to let the queue grow large but deciding on a good number of views to allow in the queue is difficult.
        // We make it a function of the number of visible views. There'll rarely be any need for the queue to grow larger than
        // the number of visible views. In fact, in most cases it can be much smaller.
        if queuedViews.count < visibleViews.count / 4 {
            queuedViews.insert(view)
        }
    }

    @objc private func clearMemory() {
        queuedViews.removeAll()
    }
}
