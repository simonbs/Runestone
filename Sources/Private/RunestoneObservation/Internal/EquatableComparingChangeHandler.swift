final class EquatableComparingChangeHandler<T: Equatable>: ChangeHandler {
    private var oldValue: T
    private let tracker: () -> T
    private let handler: (T, T) -> Void

    init(
        initialValue: T,
        tracker: @escaping () -> T,
        handler: @escaping (T, T) -> Void
    ) {
        self.oldValue = initialValue
        self.tracker = tracker
        self.handler = handler
    }

    func invoke() throws {
        let newValue = tracker()
        if newValue != oldValue {
            handler(oldValue, newValue)
            oldValue = newValue
        }
    }
}
