@testable import RunestoneObservation

final class ObservationStoreSpy: ObservationStore {
    var observations: [Observation] {
        Array(map.values)
    }

    private(set) var didAddObservation = false
    private(set) var didRemoveObservation = false
    private(set) var didRemoveAll = false

    private var map: [ObservationId: Observation] = [:]

    func addObservation(_ observation: Observation) {
        didAddObservation = true
        map[observation.id] = observation
    }

    func observation(withId observationId: ObservationId) -> Observation? {
        nil
    }

    func removeObservation(withId observationId: ObservationId) {
        didRemoveObservation = true
    }
    
    func observations(for propertyChangeId: PropertyChangeId) -> [Observation] {
        []
    }

    func removeAll() {
        didRemoveAll = true
    }
}
