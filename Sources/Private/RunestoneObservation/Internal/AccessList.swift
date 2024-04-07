struct AccessList: Sendable {
    struct Entry: @unchecked Sendable {
        let observableObservationStore: ObservationStoring

        private(set) var properties: Set<AnyKeyPath>

        init(_ observationStore: ObservationStoring, properties: Set<AnyKeyPath> = []) {
            self.observableObservationStore = observationStore
            self.properties = properties
        }

        func addObserver(
            receiving changeType: PropertyChangeType,
            changeHandler: AnyObservationChangeHandler,
            observationStore observerObservationStore: ObservationStoring
        ) -> StoredObservation {
            let observation = StoredObservation(
                properties: properties,
                changeType: changeType,
                changeHandler: changeHandler,
                observableObservationStore: observableObservationStore,
                observerObservationStore: observerObservationStore
            )
            observableObservationStore.addObservation(observation)
            observerObservationStore.addObservation(observation)
            return observation
        }

        mutating func insert(_ keyPath: AnyKeyPath) {
            properties.insert(keyPath)
        }

        func union(_ entry: Entry) -> Entry {
            Entry(observableObservationStore, properties: properties.union(entry.properties))
        }
    }

    private(set) var entries: [ObjectIdentifier: Entry] = [:]

    mutating func addAccess<Subject>(
        keyPath: PartialKeyPath<Subject>,
        observationStore: ObservationStoring
    ) {
        entries[observationStore.id, default: Entry(observationStore)].insert(keyPath)
    }

    mutating func merge(_ other: AccessList) {
        entries.merge(other.entries) { existing, entry in
            existing.union(entry)
        }
    }
}
