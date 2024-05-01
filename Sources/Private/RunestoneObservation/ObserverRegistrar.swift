public final class ObserverRegistrar {
    private let observationStore: ObservationStoring

    public init() {
        observationStore = LockingObservationStore(ObservationStore())
    }

    init(observationStore: ObservationStoring) {
        self.observationStore = observationStore
    }

    deinit {
        cancelAllObservations()
    }

    public func registerObserver<T: Equatable>(
        tracking tracker: @escaping () -> T,
        options: ObservationOptions = [],
        handler: @escaping ObservationChangeHandler<T>
    ) -> Observation {
        registerObserver(
            tracking: tracker,
            options: options,
            handler: handler
        ) { initialValue, tracker, handler in
            EquatableComparingChangeHandler(
                initialValue: initialValue,
                tracker: tracker,
                handler: handler
            )
        }
    }

    public func registerObserver<T>(
        tracking tracker: @escaping () -> T,
        options: ObservationOptions = [],
        handler: @escaping ObservationChangeHandler<T>
    ) -> Observation {
        registerObserver(
            tracking: tracker,
            options: options,
            handler: handler
        ) { initialValue, tracker, handler in
            AlwaysPublishingChangeHandler(
                initialValue: initialValue,
                tracker: tracker,
                handler: handler
            )
        }
    }
}

private extension ObserverRegistrar {
    private func registerObserver<T>(
        tracking tracker: @escaping () -> T,
        options: ObservationOptions,
        handler: @escaping ObservationChangeHandler<T>,
        makeChangeHandler: (T, @escaping () -> T, @escaping ObservationChangeHandler<T>) -> ChangeHandler
    ) -> Observation {
        let (value, accessList) = generateAccessList(tracker)
        defer {
            if options.contains(.initialValue) {
                handler(value, value)
            }
        }
        let changeHandler = makeChangeHandler(value, tracker, handler)
        let storedObservations = accessList.entries.values.map { entry in
            entry.addObserver(changeHandler: changeHandler, observationStore: observationStore)
        }
        return Observation(storedObservations)
    }

    private func cancelAllObservations() {
        for observation in observationStore.observations {
            observation.cancel()
        }
    }

    private func generateAccessList<T>(_ tracker: () -> T) -> (T, AccessList) {
        var previousAccessList = ThreadLocal.value
        ThreadLocal.value = nil
        let value = tracker()
        let scopedAccessList = ThreadLocal.value
        if var tmpPreviousAccessList = previousAccessList, let scopedAccessList {
            tmpPreviousAccessList.merge(scopedAccessList)
            previousAccessList = tmpPreviousAccessList
        }
        ThreadLocal.value = previousAccessList
        guard let scopedAccessList else {
            return (value, AccessList())
        }
        return (value, scopedAccessList)
    }
}
