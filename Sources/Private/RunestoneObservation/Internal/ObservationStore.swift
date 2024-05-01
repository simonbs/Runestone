import Foundation

final class ObservationStore: ObservationStoring {
    var observations: [StoredObservation] {
        Array(map.values)
    }

    private var map: [StoredObservation.Id: StoredObservation] = [:]
    private var lookups: [AnyKeyPath: Set<StoredObservation.Id>] = [:]

    func addObservation(_ observation: StoredObservation) {
        map[observation.id] = observation
        for keyPath in observation.properties {
            lookups[keyPath, default: []].insert(observation.id)
        }
    }

    func removeObservation(_ observation: StoredObservation) {
        map.removeValue(forKey: observation.id)
        for keyPath in observation.properties {
            guard var ids = lookups[keyPath] else {
                continue
            }
            ids.remove(observation.id)
            if ids.isEmpty {
                lookups.removeValue(forKey: keyPath)
            } else {
                lookups[keyPath] = ids
            }
        }
    }

    func observations(observing keyPath: AnyKeyPath) -> [StoredObservation] {
        guard let ids = lookups[keyPath] else {
            return []
        }
        var observations: [StoredObservation] = []
        for id in ids {
            if let observation = map[id] {
                observations.append(observation)
            }
        }
        return observations
    }
}
