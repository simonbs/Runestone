public final class Observation {
    private var storedObservations: [StoredObservation]

    init(_ storedObservations: [StoredObservation]) {
        self.storedObservations = storedObservations
    }

    public func cancel() {
        for storedObservation in storedObservations {
            storedObservation.cancel()
        }
        storedObservations.removeAll()
    }
}
