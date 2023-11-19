protocol ObservationStore {
    var observations: [Observation] { get }
    func addObservation(_ observation: Observation)
    func observation(withId observationId: ObservationId) -> Observation?
    func removeObservation(withId observationId: ObservationId)
    func observations(for propertyChangeId: PropertyChangeId) -> [Observation]
    func removeAll()
}
