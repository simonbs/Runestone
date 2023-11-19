@testable import RunestoneObservation

final class MockObserver: Observer {
    private(set) var didCancel = false

    func cancelObservation(withId observationId: ObservationId) {
        didCancel = true
    }
}
