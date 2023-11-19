@testable import RunestoneObservation
import XCTest

final class ObservableRegistryTests: XCTestCase {
    func test_it_stores_observation() {
        let observationStore = ObservationStoreSpy()
        let observer = MockObserver()
        let observable = MockObservable()
        let sut = ObservableRegistry<MockObservable>(storingIn: observationStore)
        _ = sut.registerObserver(
            observer,
            observing: \.value,
            on: observable,
            receiving: .willSet
        ) { _, _ in}
        XCTAssertTrue(observationStore.didAddObservation)
    }

    func test_it_does_not_send_initial_value_when_initialvalue_option_not_specified() {
        let observer = MockObserver()
        let observable = MockObservable()
        let sut = ObservableRegistry<MockObservable>()
        var didReceiveValue = false
        _ = sut.registerObserver(
            observer,
            observing: \.value,
            on: observable,
            receiving: .willSet
        ) { _, _ in
            didReceiveValue = true
        }
        XCTAssertFalse(didReceiveValue)
    }

    func test_it_sends_initial_value_when_initialvalue_option_specified() {
        let observer = MockObserver()
        let observable = MockObservable()
        let sut = ObservableRegistry<MockObservable>()
        var didReceiveValue = false
        _ = sut.registerObserver(
            observer,
            observing: \.value,
            on: observable,
            receiving: .willSet,
            options: .initialValue
        ) { _, _ in
            didReceiveValue = true
        }
        XCTAssertTrue(didReceiveValue)
    }

    func test_it_sends_initial_value_to_handler_when_initialvalue_option_specified() {
        let observer = MockObserver()
        let observable = MockObservable()
        observable.value = "foo"
        let sut = ObservableRegistry<MockObservable>()
        var receivedOldValue: String?
        var receivedNewValue: String?
        _ = sut.registerObserver(
            observer,
            observing: \.value,
            on: observable,
            receiving: .willSet,
            options: .initialValue
        ) { oldValue, newValue in
            receivedOldValue = oldValue
            receivedNewValue = newValue
        }
        XCTAssertEqual(receivedOldValue, "foo")
        XCTAssertEqual(receivedNewValue, "foo")
    }

    func test_it_removes_observation_from_stores_when_cancelling() {
        let observationStore = ObservationStoreSpy()
        let observer = MockObserver()
        let observable = MockObservable()
        let sut = ObservableRegistry<MockObservable>(storingIn: observationStore)
        let observationId = sut.registerObserver(
            observer,
            observing: \.value,
            on: observable,
            receiving: .willSet
        ) { _, _ in }
        sut.cancelObservation(withId: observationId)
        XCTAssertTrue(observationStore.didRemoveObservation)
    }

    func test_it_removes_all_observations_on_deinit() {
        let observationStore = ObservationStoreSpy()
        let observer = MockObserver()
        let observable = MockObservable()
        var sut: ObservableRegistry<MockObservable>? = ObservableRegistry(storingIn: observationStore)
        _ = sut?.registerObserver(
            observer,
            observing: \.value,
            on: observable,
            receiving: .willSet
        ) { _, _ in }
        sut = nil
        XCTAssertTrue(observationStore.didRemoveAll)
    }

    func test_it_invokes_cancel_on_all_observers_on_deinit() {
        let observer = MockObserver()
        let observable = MockObservable()
        var sut: ObservableRegistry<MockObservable>? = ObservableRegistry()
        _ = sut?.registerObserver(
            observer,
            observing: \.value,
            on: observable,
            receiving: .willSet
        ) { _, _ in }
        sut = nil
        XCTAssertTrue(observer.didCancel)
    }

    func test_it_invokes_observer_when_publishing_change_for_didset_change_type() {
        let observer = MockObserver()
        let observable = MockObservable()
        let sut = ObservableRegistry<MockObservable>()
        var didCallWillSetHandler = false
        var didCallDidSetHandler = false
        _ = sut.registerObserver(
            observer,
            observing: \.value,
            on: observable,
            receiving: .willSet
        ) { _, _ in
            didCallWillSetHandler = true
        }
        _ = sut.registerObserver(
            observer,
            observing: \.value,
            on: observable,
            receiving: .didSet
        ) { _, _ in
            didCallDidSetHandler = true
        }
        sut.publishChange(ofType: .didSet, changing: \.value, on: observable, from: "foo", to: "bar")
        XCTAssertFalse(didCallWillSetHandler)
        XCTAssertTrue(didCallDidSetHandler)
    }

    func test_it_invokes_observer_when_publishing_change_for_willset_change_type() {
        let observer = MockObserver()
        let observable = MockObservable()
        let sut = ObservableRegistry<MockObservable>()
        var didCallWillSetHandler = false
        var didCallDidSetHandler = false
        _ = sut.registerObserver(
            observer,
            observing: \.value,
            on: observable,
            receiving: .willSet
        ) { _, _ in
            didCallWillSetHandler = true
        }
        _ = sut.registerObserver(
            observer,
            observing: \.value,
            on: observable,
            receiving: .didSet
        ) { _, _ in
            didCallDidSetHandler = true
        }
        sut.publishChange(ofType: .willSet, changing: \.value, on: observable, from: "foo", to: "bar")
        XCTAssertTrue(didCallWillSetHandler)
        XCTAssertFalse(didCallDidSetHandler)
    }

    func test_it_passes_old_value_and_new_value_when_invoking_observer() {
        let observer = MockObserver()
        let observable = MockObservable()
        let sut = ObservableRegistry<MockObservable>()
        var receivedOldValue: String?
        var receivedNewValue: String?
        _ = sut.registerObserver(
            observer,
            observing: \.value,
            on: observable,
            receiving: .didSet
        ) { oldValue, newValue in
            receivedOldValue = oldValue
            receivedNewValue = newValue
        }
        sut.publishChange(ofType: .didSet, changing: \.value, on: observable, from: "foo", to: "bar")
        XCTAssertEqual(receivedOldValue, "foo")
        XCTAssertEqual(receivedNewValue, "bar")
    }
}
