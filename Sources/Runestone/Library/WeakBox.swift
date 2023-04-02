import Foundation

final class WeakBox<Value: AnyObject> {
    private(set) weak var value: Value?

    init(_ value: Value? = nil) {
        self.value = value
    }
}
