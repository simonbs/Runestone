@testable import _RunestoneObservation
import XCTest

final class ObserverRegistrarTests: XCTestCase {
    func test_it_stores_observation() {
        let observationStore = ObservationStoreSpy()
        let sut = ObserverRegistrar(observationStore: observationStore)
        let observable = MockObservable()
        _ = sut.registerObserver(tracking: { observable.str }) { _, _ in }
        XCTAssertNotNil(observationStore.addedObservationId)
    }

    func test_it_cancels_observations_upon_deinit() {
        let observationStore = ObservationStoreSpy()
        var sut: ObserverRegistrar? = ObserverRegistrar(observationStore: observationStore)
        let observable = MockObservable()
        _ = sut?.registerObserver(tracking: { observable.str }) { _, _ in }
        sut = nil
        XCTAssertNotNil(observationStore.removedObservationId)
    }

    func test_it_does_not_send_initial_value_when_initialvalue_option_not_specified() {
        let observationStore = ObservationStoreSpy()
        let observable = MockObservable()
        let sut = ObserverRegistrar(observationStore: observationStore)
        var didReceiveValue = false
        _ = sut.registerObserver(tracking: { observable.str }, options: []) { _, _ in
            didReceiveValue = true
        }
        XCTAssertFalse(didReceiveValue)
    }
    
    func test_it_sends_initial_value_when_initialvalue_option_specified() {
        let observationStore = ObservationStoreSpy()
        let observable = MockObservable()
        let sut = ObserverRegistrar(observationStore: observationStore)
        var didReceiveValue = false
        _ = sut.registerObserver(tracking: { observable.str }, options: .initialValue) { _, _ in
            didReceiveValue = true
        }
        XCTAssertTrue(didReceiveValue)
    }
}
