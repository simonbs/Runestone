import Foundation

final class DictionaryObservableStore: ObservableStore {
    private final class WeakObservable {
        private(set) weak var observable: (any Observable)?

        init(_ observable: any Observable) {
            self.observable = observable
        }
    }

    var observationIds: [ObservationId] {
        Array(map.keys)
    }

    private var map: [ObservationId: WeakObservable] = [:]

    func addObservable(_ observable: some Observable, for observationId: ObservationId) {
        map[observationId] = WeakObservable(observable)
    }
    
    func removeObservable(for observationId: ObservationId) {
        map.removeValue(forKey: observationId)
    }
    
    func observable(for observationId: ObservationId) -> (any Observable)? {
        map[observationId]?.observable
    }
    
    func removeAll() {
        map.removeAll()
    }
}
