public protocol Observable: AnyObject {
    func registerObserver<T>(
        _ observer: some Observer,
        observing keyPath: KeyPath<Self, T>,
        receiving changeType: PropertyChangeType,
        options: ObservationOptions,
        handler: @escaping ObservationChangeHandler<T>
    ) -> ObservationId
    func cancelObservation(withId observationId: ObservationId)
}
