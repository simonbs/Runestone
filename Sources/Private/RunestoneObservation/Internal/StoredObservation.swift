import Foundation

struct StoredObservation {
    struct Id: Hashable {
        private let id = UUID()
    }
    
    let id = Id()
    let properties: Set<AnyKeyPath>
    let changeType: PropertyChangeType
    let changeHandler: AnyObservationChangeHandler

    private let observableObservationStore: ObservationStoring
    private let observerObservationStore: ObservationStoring

    init(
        properties: Set<AnyKeyPath>,
        changeType: PropertyChangeType,
        changeHandler: AnyObservationChangeHandler,
        observableObservationStore: ObservationStoring,
        observerObservationStore: ObservationStoring
    ) {
        self.properties = properties
        self.changeType = changeType
        self.changeHandler = changeHandler
        self.observableObservationStore = observableObservationStore
        self.observerObservationStore = observerObservationStore
    }

    func cancel() {
        observableObservationStore.removeObservation(self)
        observerObservationStore.removeObservation(self)
    }
}
