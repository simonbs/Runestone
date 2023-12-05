@testable import _RunestoneObservation
import XCTest

final class DictionaryObservableStoreTests: XCTestCase {
    func test_it_stores_observable() {
        let observable = MockObservable()
        let observationId = ObservationId()
        let sut = DictionaryObservableStore()
        XCTAssertEqual(sut.observationIds.count, 0)
        sut.addObservable(observable, for: observationId)
        XCTAssertEqual(sut.observationIds.count, 1)
    }

    func test_it_removes_observable() {
        let observable = MockObservable()
        let observationId = ObservationId()
        let sut = DictionaryObservableStore()
        sut.addObservable(observable, for: observationId)
        XCTAssertEqual(sut.observationIds.count, 1)
        sut.removeObservable(for: observationId)
        XCTAssertEqual(sut.observationIds.count, 0)
    }

    func test_it_returns_observation_ids() {
        let observable = MockObservable()
        let observationId = ObservationId()
        let sut = DictionaryObservableStore()
        sut.addObservable(observable, for: observationId)
        XCTAssertEqual(sut.observationIds, [observationId])
    }

    func test_it_returns_stored_observable() {
        let observable = MockObservable()
        let observationId = ObservationId()
        let sut = DictionaryObservableStore()
        sut.addObservable(observable, for: observationId)
        let returnedObservable = sut.observable(for: observationId)
        XCTAssertIdentical(returnedObservable, observable)
    }

    func test_it_removes_all_observables() {
        let observable1 = MockObservable()
        let observable2 = MockObservable()
        let observationId1 = ObservationId()
        let observationId2 = ObservationId()
        let sut = DictionaryObservableStore()
        sut.addObservable(observable1, for: observationId1)
        sut.addObservable(observable2, for: observationId2)
        XCTAssertEqual(sut.observationIds.count, 2)
        sut.removeAll()
        XCTAssertEqual(sut.observationIds.count, 0)
    }
}
