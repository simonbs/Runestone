final class LockingObservationStore<DecoratedObservationStore: ObservationStoring>: ObservationStoring {
    var observations: [StoredObservation] {
        state.withCriticalRegion { $0.observations }
    }

    private let state: ManagedCriticalState<DecoratedObservationStore>

    init(_ observationStore: DecoratedObservationStore) {
        self.state = ManagedCriticalState(observationStore)
    }

    func addObservation(_ observation: StoredObservation) {
        state.withCriticalRegion { $0.addObservation(observation) }
    }

    func removeObservation(_ observation: StoredObservation) {
        state.withCriticalRegion { $0.removeObservation(observation) }
    }

    func observations(
        observing keyPath: AnyKeyPath,
        receiving changeType: PropertyChangeType
    ) -> [StoredObservation] {
        state.withCriticalRegion { $0.observations(observing: keyPath, receiving: changeType) }
    }
}
