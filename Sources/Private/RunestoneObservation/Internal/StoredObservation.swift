import Foundation

struct StoredObservation {
    struct Id: Hashable {
        private let id = UUID()
    }
    
    let id = Id()
    let properties: Set<AnyKeyPath>
    let changeHandler: ChangeHandler

    private let observableObservationStore: ObservationStoring
    private let observerObservationStore: ObservationStoring

    init(
        properties: Set<AnyKeyPath>,
        changeHandler: ChangeHandler,
        observableObservationStore: ObservationStoring,
        observerObservationStore: ObservationStoring
    ) {
        self.properties = properties
        self.changeHandler = changeHandler
        self.observableObservationStore = observableObservationStore
        self.observerObservationStore = observerObservationStore
    }

    func cancel() {
        observableObservationStore.removeObservation(self)
        observerObservationStore.removeObservation(self)
    }
}
