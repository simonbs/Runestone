@testable import _RunestoneObservation
import XCTest

final class LockingObservationStoreTests: XCTestCase {
    func test_it_decorates_add_observation() throws {
        let observationStore = ObservationStoreSpy()
        let sut = LockingObservationStore(observationStore)
        let changeHandler = MockChangeHandler()
        let storedObservation = StoredObservation(
            properties: [], 
            changeHandler: changeHandler,
            observableObservationStore: sut,
            observerObservationStore: sut
        )
        sut.addObservation(storedObservation)
        XCTAssertNotNil(observationStore.addedObservationId)
    }

    func test_it_decorates_remove_observation() throws {
        let observationStore = ObservationStoreSpy()
        let sut = LockingObservationStore(observationStore)
        let changeHandler = MockChangeHandler()
        let storedObservation = StoredObservation(
            properties: [],
            changeHandler: changeHandler,
            observableObservationStore: sut,
            observerObservationStore: sut
        )
        sut.addObservation(storedObservation)
        sut.removeObservation(storedObservation)
        XCTAssertNotNil(observationStore.removedObservationId)
    }

    func test_it_decorates_observations_observing_receiving() throws {
        let observationStore = ObservationStoreSpy()
        let sut = LockingObservationStore(observationStore)
        _ = sut.observations(observing: \MockObservable.str)
        XCTAssertNotNil(observationStore.didCallObservationsObservingReceiving)
    }
}
