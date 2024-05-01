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

    public func registerObserver<T>(
        tracking tracker: @escaping () -> T,
        options: ObservationOptions = [],
        handler: @escaping ObservationChangeHandler<T>
    ) -> Observation {
        guard let (value, accessList) = generateAccessList(tracker) else {
            fatalError("Failed to generate property access list. Make sure not to pass a closure to the observe(_:) function.")
        }
        defer {
            if options.contains(.initialValue) {
                handler(value, value)
            }
        }
        let changeHandler = ValueComparingChangeHandler(
            initialValue: value, 
            tracker: tracker,
            handler: handler
        )
        let storedObservations = accessList.entries.values.map { entry in
            entry.addObserver(changeHandler: changeHandler, observationStore: observationStore)
        }
        return Observation(storedObservations)
    }
}

private extension ObserverRegistrar {
    private func cancelAllObservations() {
        for observation in observationStore.observations {
            observation.cancel()
        }
    }

    private func generateAccessList<T>(_ tracker: () -> T) -> (T, AccessList)? {
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
            return nil
        }
        return (value, scopedAccessList)
    }
}
