@testable import _RunestoneObservation

final class ObservationStoreSpy: ObservationStoring {
    private(set) var observations: [StoredObservation] = []
    private(set) var addedObservationId: StoredObservation.Id?
    private(set) var removedObservationId: StoredObservation.Id?
    private(set) var didCallObservationsObservingReceiving = false

    func addObservation(_ observation: StoredObservation) {
        addedObservationId = observation.id
        observations.append(observation)
    }

    func removeObservation(_ observation: StoredObservation) {
        removedObservationId = observation.id
        observations.removeAll { $0.id == observation.id }
    }

    func observations(
        observing keyPath: AnyKeyPath,
        receiving changeType: PropertyChangeType
    ) -> [StoredObservation] {
        didCallObservationsObservingReceiving = true
        return observations.filter { $0.properties.contains(keyPath) && $0.changeType == changeType }
    }
}
