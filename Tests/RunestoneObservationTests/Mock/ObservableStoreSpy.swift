@testable import _RunestoneObservation

final class ObservableStoreSpy: ObservableStore {
    var observationIds: [ObservationId] {
        Array(map.keys)
    }

    private(set) var addedObservationId: ObservationId?
    private(set) var removedObservationId: ObservationId?
    private(set) var didRemoveAll = false

    private var map: [ObservationId: any Observable] = [:]

    func addObservable(_ observable: some Observable, for observationId: ObservationId) {
        addedObservationId = observationId
        map[observationId] = observable
    }

    func removeObservable(for observationId: ObservationId) {
        removedObservationId = observationId
    }

    func observable(for observationId: ObservationId) -> (any Observable)? {
        map[observationId]
    }

    func removeAll() {
        didRemoveAll = true
    }
}
