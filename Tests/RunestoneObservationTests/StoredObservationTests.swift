@testable import _RunestoneObservation
import XCTest

final class StoredObservationTests: XCTestCase {
    func test_it_has_a_unique_id() {
        let observableObservationStore = ObservationStoreSpy()
        let observerObservationStore = ObservationStoreSpy()
        let changeHandlerA = MockChangeHandler()
        let changeHandlerB = MockChangeHandler()
        let a = StoredObservation(
            properties: [],
            changeHandler: changeHandlerA,
            observableObservationStore: observableObservationStore,
            observerObservationStore: observerObservationStore
        )
        let b = StoredObservation(
            properties: [],
            changeHandler: changeHandlerB,
            observableObservationStore: observableObservationStore,
            observerObservationStore: observerObservationStore
        )
        XCTAssertNotEqual(a.id, b.id)
    }

    func test_it_removes_itself_from_observation_stores() {
        let observableObservationStore = ObservationStoreSpy()
        let observerObservationStore = ObservationStoreSpy()
        let changeHandler = MockChangeHandler()
        let sut = StoredObservation(
            properties: [],
            changeHandler: changeHandler,
            observableObservationStore: observableObservationStore,
            observerObservationStore: observerObservationStore
        )
        observableObservationStore.addObservation(sut)
        observerObservationStore.addObservation(sut)
        XCTAssertFalse(observableObservationStore.observations.isEmpty)
        XCTAssertFalse(observerObservationStore.observations.isEmpty)
        sut.cancel()
        XCTAssertTrue(observableObservationStore.observations.isEmpty)
        XCTAssertTrue(observerObservationStore.observations.isEmpty)
    }
}
