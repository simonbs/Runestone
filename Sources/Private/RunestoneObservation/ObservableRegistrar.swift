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
        handler: () -> Void
    ) {
        handler()
        publishChange(changing: keyPath, on: observable)
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

    private func publishChange<Subject, T>(changing keyPath: KeyPath<Subject, T>, on subject: Subject) {
        do {
            let observations = observationStore.observations(observing: keyPath)
            for observation in observations {
                try observation.changeHandler.invoke()
            }
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}
