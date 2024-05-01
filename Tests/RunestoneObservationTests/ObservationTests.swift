@testable import _RunestoneObservation
import XCTest

final class ObservationTests: XCTestCase {
    func test_it_removes_observation_from_observation_store_when_cancelling() {
        let observationStore = ObservationStoreSpy()
        let observerRegistrar = ObserverRegistrar(observationStore: observationStore)
        let observable = MockObservable()
        let sut = observerRegistrar.registerObserver(tracking: { observable.str }) { _, _ in }
        XCTAssertNotNil(observationStore.addedObservationId)
        sut.cancel()
        XCTAssertNotNil(observationStore.removedObservationId)
    }
}
