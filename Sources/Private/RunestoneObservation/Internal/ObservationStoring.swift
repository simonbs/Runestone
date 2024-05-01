protocol ObservationStoring {
    var id: ObjectIdentifier { get }
    var observations: [StoredObservation] { get }
    func addObservation(_ observation: StoredObservation)
    func removeObservation(_ observation: StoredObservation)
    func observations(observing keyPath: AnyKeyPath) -> [StoredObservation]
}

extension ObservationStoring where Self: AnyObject {
    var id: ObjectIdentifier {
        ObjectIdentifier(self)
    }
}
