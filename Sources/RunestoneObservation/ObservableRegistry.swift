public final class ObservableRegistry<ObservableType: Observable> {
    private var observationStore: ObservationStore

    public convenience init() {
        self.init(storingIn: DictionaryObservationStore())
    }

    init<ObservationStoreType: ObservationStore>(storingIn observationStore: ObservationStoreType) {
        self.observationStore = observationStore
    }

    deinit {
        deregisterAllObservers()
    }

    public func publishChange<T>(
        ofType changeType: PropertyChangeType,
        changing keyPath: KeyPath<ObservableType, T>,
        on observable: ObservableType,
        from oldValue: T,
        to newValue: T
    ) {
        skipComparisonAndPublishChange(
            ofType: changeType,
            changing: keyPath,
            on: observable,
            from: oldValue,
            to: newValue
        )
    }

    public func publishChange<T: Equatable>(
        ofType changeType: PropertyChangeType,
        changing keyPath: KeyPath<ObservableType, T>,
        on observable: ObservableType,
        from oldValue: T,
        to newValue: T
    ) {
        guard oldValue != newValue else {
            return
        }
        skipComparisonAndPublishChange(
            ofType: changeType,
            changing: keyPath,
            on: observable,
            from: oldValue,
            to: newValue
        )
    }

    public func registerObserver<T>(
        _ observer: some Observer,
        observing keyPath: KeyPath<ObservableType, T>,
        on observable: ObservableType,
        receiving changeType: PropertyChangeType,
        options: ObservationOptions = [],
        handler: @escaping ObservationChangeHandler<T>
    ) -> ObservationId {
        let propertyChangeId = PropertyChangeId(for: observable, publishing: changeType, of: keyPath)
        let observation = Observation(
            observer: observer,
            propertyChangeId: propertyChangeId,
            handler: handler
        )
        observationStore.addObservation(observation)
        if options.contains(.initialValue) {
            let initialValue = observable[keyPath: keyPath]
            handler(initialValue, initialValue)
        }
        return observation.id
    }

    public func cancelObservation(withId observationId: ObservationId) {
        observationStore.removeObservation(withId: observationId)
    }
}

private extension ObservableRegistry {
    private func skipComparisonAndPublishChange<T>(
        ofType changeType: PropertyChangeType,
        changing keyPath: KeyPath<ObservableType, T>,
        on observable: ObservableType,
        from oldValue: T,
        to newValue: T
    ) {
        do {
            let propertyChangeId = PropertyChangeId(for: observable, publishing: changeType, of: keyPath)
            let observations = observationStore.observations(for: propertyChangeId)
            for observation in observations {
                try observation.handler.invoke(changingFrom: oldValue, to: newValue)
            }
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    private func deregisterAllObservers() {
        for observation in observationStore.observations {
            observation.invokeCancelOnObserver()
        }
        observationStore.removeAll()
    }
}
