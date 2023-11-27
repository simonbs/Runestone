@testable import RunestoneObservation
import XCTest

final class ObserverRegistryTests: XCTestCase {
    func test_it_stores_observation() {
        let observableStore = ObservableStoreSpy()
        let sut = ObserverRegistry(observableStore: observableStore)
        let observable = MockObservable()
        sut.registerObserver(observing: \.str, of: observable, receiving: .willSet) { _, _ in }
        XCTAssertNotNil(observableStore.addedObservationId)
    }

    func test_it_removes_observation_when_cancelling() {
        let observableStore = ObservableStoreSpy()
        let sut = ObserverRegistry(observableStore: observableStore)
        let observable = MockObservable()
        sut.registerObserver(observing: \.str, of: observable, receiving: .willSet) { _, _ in }
        XCTAssertNotNil(observableStore.addedObservationId)
        sut.cancelObservation(withId: observableStore.addedObservationId!)
        XCTAssertNotNil(observableStore.removedObservationId)
    }

    func test_it_does_not_forward_cancellation_to_observable() {
        // Forwarding the cancel to the observable could cause the ObservationRegistry and
        // the observable to end up in an infinite loop where they keep calling each other.
        let observableStore = ObservableStoreSpy()
        let sut = ObserverRegistry(observableStore: observableStore)
        let observable = MockObservable()
        sut.registerObserver(observing: \.str, of: observable, receiving: .willSet) { _, _ in }
        sut.cancelObservation(withId: observableStore.addedObservationId!)
        XCTAssertFalse(observable.didCancel)
    }

    func test_it_cancels_observations_upon_deinit() {
        let observableStore = ObservableStoreSpy()
        var sut: ObserverRegistry? = ObserverRegistry(observableStore: observableStore)
        let observable = MockObservable()
        sut?.registerObserver(observing: \.str, of: observable, receiving: .willSet) { _, _ in }
        sut = nil
        XCTAssertTrue(observable.didCancel)
    }

    func test_it_removes_all_observations_on_deinit() {
        let observableStore = ObservableStoreSpy()
        var sut: ObserverRegistry? = ObserverRegistry(observableStore: observableStore)
        let observable = MockObservable()
        sut?.registerObserver(observing: \.str, of: observable, receiving: .willSet) { _, _ in }
        sut = nil
        XCTAssertTrue(observableStore.didRemoveAll)
    }
}
