import Foundation

final class ValueComparingChangeHandler: ChangeHandler {
    private final class EquatableChangeHandler<T: Equatable>: ChangeHandler {
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

    private final class NonEquatableChangeHandler<T>: ChangeHandler {
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
            handler(oldValue, newValue)
            oldValue = newValue
        }
    }

    private let changeHandler: ChangeHandler

    init<T>(
        initialValue: T,
        tracker: @escaping () -> T,
        handler: @escaping (T, T) -> Void
    ) where T: Equatable {
        changeHandler = EquatableChangeHandler(
            initialValue: initialValue, 
            tracker: tracker,
            handler: handler
        )
    }

    init<T>(
        initialValue: T,
        tracker: @escaping () -> T,
        handler: @escaping (T, T) -> Void
    ) {
        changeHandler = NonEquatableChangeHandler(
            initialValue: initialValue,
            tracker: tracker,
            handler: handler
        )
    }

    func invoke() throws {
        try changeHandler.invoke()
    }
}
