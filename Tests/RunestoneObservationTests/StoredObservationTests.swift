@testable import _RunestoneObservation
import XCTest

final class StoredObservationTests: XCTestCase {
    func test_it_has_a_unique_id() {
        let observableObservationStore = ObservationStoreSpy()
        let observerObservationStore = ObservationStoreSpy()
        let changeHandlerA = AnyObservationChangeHandler { (_: String, _: String) in }
        let changeHandlerB = AnyObservationChangeHandler { (_: String, _: String) in }
        let a = StoredObservation(
            properties: [],
            changeType: .didSet, 
            changeHandler: changeHandlerA,
            observableObservationStore: observableObservationStore,
            observerObservationStore: observerObservationStore
        )
        let b = StoredObservation(
            properties: [],
            changeType: .didSet,
            changeHandler: changeHandlerB,
            observableObservationStore: observableObservationStore,
            observerObservationStore: observerObservationStore
        )
        XCTAssertNotEqual(a.id, b.id)
    }

    func test_it_removes_itself_from_observation_stores() {
        let observableObservationStore = ObservationStoreSpy()
        let observerObservationStore = ObservationStoreSpy()
        let changeHandler = AnyObservationChangeHandler { (_: String, _: String) in }
        let sut = StoredObservation(
            properties: [],
            changeType: .didSet,
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
