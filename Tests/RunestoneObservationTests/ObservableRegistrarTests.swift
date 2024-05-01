@testable import _RunestoneObservation
import XCTest

final class ObservableRegistrarTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ThreadLocal.value = nil
    }

    func test_it_adds_access_to_access_list() {
        let observableObservationStore = ObservationStoreSpy()
        let observable = MockObservable()
        let sut = ObservableRegistrar(observationStore: observableObservationStore)
        sut.access(\.str, on: observable)
        XCTAssertNotNil(ThreadLocal.value)
    }

    func test_it_cancels_all_observations_on_deinit() {
        let observableObservationStore = ObservationStoreSpy()
        let observerObservationStore = ObservationStoreSpy()
        let observable = MockObservable()
        var sut: ObservableRegistrar? = ObservableRegistrar(observationStore: observableObservationStore)
        sut?.access(\.str, on: observable)
        XCTAssertNotNil(ThreadLocal.value)
        let entry = ThreadLocal.value?.entries.first?.value
        let changeHandler = MockChangeHandler()
        _ = entry?.addObserver(
            changeHandler: changeHandler,
            observationStore: observerObservationStore
        )
        XCTAssertFalse(observableObservationStore.observations.isEmpty)
        sut = nil
        XCTAssertTrue(observableObservationStore.observations.isEmpty)
    }
}
