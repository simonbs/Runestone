public final class ObservableRegistrar {
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

    public func withMutation<Subject, T>(
        of keyPath: KeyPath<Subject, T>,
        on observable: Subject,
        changingFrom oldValue: T,
        to newValue: T,
        using handler: () -> Void
    ) {
        publishChange(
            ofType: .willSet,
            changing: keyPath, 
            on: observable,
            from: oldValue,
            to: newValue
        )
        handler()
        publishChange(
            ofType: .didSet,
            changing: keyPath,
            on: observable,
            from: oldValue,
            to: newValue
        )
    }

    public func withMutation<Subject, T: Equatable>(
        of keyPath: KeyPath<Subject, T>,
        on observable: Subject,
        changingFrom oldValue: T,
        to newValue: T,
        handler: () -> Void
    ) {
        let isDifferentValue = oldValue != newValue
        if isDifferentValue {
            publishChange(
                ofType: .willSet,
                changing: keyPath,
                on: observable,
                from: oldValue,
                to: newValue
            )
        }
        handler()
        if isDifferentValue {
            publishChange(
                ofType: .didSet,
                changing: keyPath,
                on: observable,
                from: oldValue,
                to: newValue
            )
        }
    }

    public func access<Subject, T>(_ keyPath: KeyPath<Subject, T>, on subject: Subject) {
        if ThreadLocal.value == nil {
            ThreadLocal.value = AccessList()
        }
        ThreadLocal.value?.addAccess(keyPath: keyPath, observationStore: observationStore)
    }
}

private extension ObservableRegistrar {
    private func cancelAllObservations() {
        for observation in observationStore.observations {
            observation.cancel()
        }
    }

    private func publishChange<Subject, T>(
        ofType changeType: PropertyChangeType,
        changing keyPath: KeyPath<Subject, T>,
        on subject: Subject,
        from oldValue: T,
        to newValue: T
    ) {
        do {
            let observations = observationStore.observations(observing: keyPath, receiving: changeType)
            for observation in observations {
                try observation.changeHandler.invoke(changingFrom: oldValue, to: newValue)
            }
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}
