import _RunestoneMultiPlatform
#if os(iOS)
import UIKit
#endif

protocol ReusableValue: Hashable {
    static func makeReusableValue() -> Self
    func prepareForReuse()
}

final class ReuseQueue<Key: Hashable, Value: ReusableValue> {
    private(set) var activeValues: [Key: Value] = [:]

    private var queuedValues: Set<Value> = []

    init() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearMemory),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        #endif
    }

    deinit {
        #if os(iOS)
        NotificationCenter.default.removeObserver(self)
        #endif
    }

    func enqueueValues(withKeys keys: Set<Key>) {
        for key in keys {
            if let value = activeValues.removeValue(forKey: key) {
                value.prepareForReuse()
                queueValueIfNeeded(value)
            }
        }
    }

    func dequeueValue(forKey key: Key) -> Value {
        if let value = activeValues[key] {
            return value
        } else if !queuedValues.isEmpty {
            let value = queuedValues.removeFirst()
            activeValues[key] = value
            return value
        } else {
            let value = Value.makeReusableValue()
            activeValues[key] = value
            return value
        }
    }

    private func queueValueIfNeeded(_ value: Value) {
        // There is no need to let the queue grow large but deciding on a good number of
        // values to allow in the queue is difficult. We make it a function of the number
        // of active values. There will rarely be any need for the queue to grow larger
        // than the number of active values and in most cases it can be much smaller.
        if queuedValues.count < activeValues.count / 4 {
            queuedValues.insert(value)
        }
    }

    #if os(iOS)
    @objc private func clearMemory() {
        queuedValues.removeAll()
    }
    #endif
}
