import Foundation

final class DictionaryObservationStore: ObservationStore {
    var observations: [Observation] {
        Array(observationIdMap.values)
    }

    private var propertyChangeIdMap: [PropertyChangeId: [Observation]] = [:]
    private var observationIdMap: [ObservationId: Observation] = [:]

    func addObservation(_ observation: Observation) {
        let propertyChangeId = observation.propertyChangeId
        observationIdMap[observation.id] = observation
        propertyChangeIdMap[propertyChangeId] = (propertyChangeIdMap[propertyChangeId] ?? []) + [observation]
    }

    func observation(withId observationId: ObservationId) -> Observation? {
        observationIdMap[observationId]
    }

    func removeObservation(withId observationId: ObservationId) {
        guard let observation = observationIdMap[observationId] else {
            return
        }
        observationIdMap.removeValue(forKey: observationId)
        var observations = propertyChangeIdMap[observation.propertyChangeId] ?? []
        observations.removeAll { $0.id == observation.id }
        if !observations.isEmpty {
            propertyChangeIdMap[observation.propertyChangeId] = observations
        } else {
            propertyChangeIdMap.removeValue(forKey: observation.propertyChangeId)
        }
    }

    func observations(for propertyChangeId: PropertyChangeId) -> [Observation] {
        propertyChangeIdMap[propertyChangeId] ?? []
    }

    func removeAll() {
        propertyChangeIdMap.removeAll()
        observationIdMap.removeAll()
    }
}
