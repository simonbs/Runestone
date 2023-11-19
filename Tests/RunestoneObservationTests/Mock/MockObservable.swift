@testable import RunestoneObservation

final class MockObservable: Observable {
    var value = "foo"

    private(set) var didCancel = false

    func registerObserver<T>(
        _ observer: some Observer,
        observing keyPath: KeyPath<MockObservable, T>,
        receiving changeType: PropertyChangeType,
        options: ObservationOptions,
        handler: @escaping ObservationChangeHandler<T>
    ) -> ObservationId {
         ObservationId()
    }
    
    func cancelObservation(withId observationId: ObservationId) {
        didCancel = true
    }
}
