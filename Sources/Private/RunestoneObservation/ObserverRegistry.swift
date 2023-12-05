package final class ObserverRegistry: Observer {
    private var observableStore: ObservableStore

    package convenience init() {
        self.init(observableStore: DictionaryObservableStore())
    }

    init(observableStore: ObservableStore) {
        self.observableStore = observableStore
    }

    package func registerObserver<ObservableType: Observable, T>(
        observing keyPath: KeyPath<ObservableType, T>,
        of observable: ObservableType,
        receiving changeType: PropertyChangeType,
        options: ObservationOptions = [],
        handler: @escaping ObservationChangeHandler<T>
    ) {
        let observationId = observable.registerObserver(
            self,
            observing: keyPath,
            receiving: changeType,
            options: options,
            handler: handler
        )
        observableStore.addObservable(observable, for: observationId)
    }

    package func cancelObservation(withId observationId: ObservationId) {
        observableStore.removeObservable(for: observationId)
    }

    deinit {
        deregisterFromAllObservables()
    }
}

private extension ObserverRegistry {
    private func deregisterFromAllObservables() {
        for observationId in observableStore.observationIds {
            let observable = observableStore.observable(for: observationId)
            observable?.cancelObservation(withId: observationId)
        }
        observableStore.removeAll()
    }
}
