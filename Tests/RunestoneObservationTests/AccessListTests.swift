@testable import _RunestoneObservation
import XCTest

final class AccessListTests: XCTestCase {
    func test_it_adds_access() {
        let observationStore = ObservationStoreSpy()
        var sut = AccessList()
        sut.addAccess(keyPath: \MockObservable.str, observationStore: observationStore)
        XCTAssertEqual(sut.entries.count, 1)
    }

    func test_it_inserts_key_path_into_existing_entry() {
        let observationStore = ObservationStoreSpy()
        var sut = AccessList()
        sut.addAccess(keyPath: \MockObservable.str, observationStore: observationStore)
        sut.addAccess(keyPath: \MockObservable.equatableObj, observationStore: observationStore)
        XCTAssertEqual(sut.entries.count, 1)
    }

    func test_it_adds_entry_for_each_observation_store() {
        let observationStoreA = ObservationStoreSpy()
        let observationStoreB = ObservationStoreSpy()
        var sut = AccessList()
        sut.addAccess(keyPath: \MockObservable.str, observationStore: observationStoreA)
        sut.addAccess(keyPath: \MockObservable.equatableObj, observationStore: observationStoreB)
        XCTAssertEqual(sut.entries.count, 2)
    }

    func test_it_merges_access_lists() {
        let observationStoreA = ObservationStoreSpy()
        let observationStoreB = ObservationStoreSpy()
        var other = AccessList()
        other.addAccess(keyPath: \MockObservable.str, observationStore: observationStoreA)
        XCTAssertEqual(other.entries.count, 1)
        var sut = AccessList()
        sut.addAccess(keyPath: \MockObservable.str, observationStore: observationStoreB)
        sut.addAccess(keyPath: \MockObservable.equatableObj, observationStore: observationStoreB)
        sut.merge(other)
        XCTAssertEqual(sut.entries.count, 2)
    }

    func test_it_inserts_key_path() {
        let observationStore = ObservationStoreSpy()
        var sut = AccessList()
        sut.addAccess(keyPath: \MockObservable.str, observationStore: observationStore)
        var entry = sut.entries.first!.value
        XCTAssertEqual(entry.properties.count, 1)
        entry.insert(\MockObservable.equatableObj)
        XCTAssertEqual(entry.properties.count, 2)
    }

    func test_it_creates_union_of_entry() {
        let observationStore = ObservationStoreSpy()
        var other = AccessList()
        other.addAccess(keyPath: \MockObservable.equatableObj, observationStore: observationStore)
        var sut = AccessList()
        sut.addAccess(keyPath: \MockObservable.str, observationStore: observationStore)
        let entry = sut.entries.first!.value
        let unionEntry = entry.union(other.entries.first!.value)
        XCTAssertEqual(unionEntry.properties.count, 2)
    }

    func test_it_adds_observation_to_both_observation_stores() {
        let observableObservationStore = ObservationStoreSpy()
        let observerObservationStore = ObservationStoreSpy()
        var sut = AccessList()
        sut.addAccess(keyPath: \MockObservable.str, observationStore: observableObservationStore)
        let entry = sut.entries.first!.value
        let changeHandler = AnyObservationChangeHandler { (_: String, _: String) in }
        _ = entry.addObserver(
            receiving: .didSet,
            changeHandler: changeHandler,
            observationStore: observerObservationStore
        )
        XCTAssertEqual(observableObservationStore.observations.count, 1)
        XCTAssertEqual(observerObservationStore.observations.count, 1)
    }
}
