public protocol Observer: AnyObject {
    func cancelObservation(withId observationId: ObservationId)
}
