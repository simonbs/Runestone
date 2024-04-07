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
        tracking tracker: () -> T,
        receiving changeType: PropertyChangeType,
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
        let changeHandler = AnyObservationChangeHandler(handler)
        let storedObservations = accessList.entries.values.map { entry in
            entry.addObserver(
                receiving: changeType,
                changeHandler: changeHandler,
                observationStore: observationStore
            )
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
        var accessList: AccessList?
        let value = withUnsafeMutablePointer(to: &accessList) { ptr in
            let previous = ThreadLocal.value
            ThreadLocal.value = UnsafeMutableRawPointer(ptr)
            defer {
                if let scoped = ptr.pointee, let previous {
                    if var prevList = previous.assumingMemoryBound(to: AccessList?.self).pointee {
                        prevList.merge(scoped)
                        previous.assumingMemoryBound(to: AccessList?.self).pointee = prevList
                    } else {
                        previous.assumingMemoryBound(to: AccessList?.self).pointee = scoped
                    }
                }
                ThreadLocal.value = previous
            }
            return tracker()
        }
        guard let accessList else {
            return nil
        }
        return (value, accessList)
    }
}
