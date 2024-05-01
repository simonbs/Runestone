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
        let changeHandler = AnyObservationChangeHandler { (_: String, _: String) in }
        _ = entry?.addObserver(
            receiving: .willSet,
            changeHandler: changeHandler,
            observationStore: observerObservationStore
        )
        XCTAssertFalse(observableObservationStore.observations.isEmpty)
        sut = nil
        XCTAssertTrue(observableObservationStore.observations.isEmpty)
    }

    func test_it_passes_old_value_and_new_value_when_invoking_observer() {
        var receivedOldValue: String?
        var receivedNewValue: String?
        let observableObservationStore = ObservationStoreSpy()
        let observerObservationStore = ObservationStoreSpy()
        let observable = MockObservable()
        let sut = ObservableRegistrar(observationStore: observableObservationStore)
        sut.access(\.str, on: observable)
        XCTAssertNotNil(ThreadLocal.value)
        let entry = ThreadLocal.value?.entries.first?.value
        let didSetChangeHandler = AnyObservationChangeHandler { (oldValue: String, newValue: String) in
            receivedOldValue = oldValue
            receivedNewValue = newValue
        }
        _ = entry?.addObserver(
            receiving: .didSet,
            changeHandler: didSetChangeHandler,
            observationStore: observerObservationStore
        )
        sut.withMutation(of: \.str, on: observable, changingFrom: "foo", to: "bar") {}
        XCTAssertEqual(receivedOldValue, "foo")
        XCTAssertEqual(receivedNewValue, "bar")
    }

    func test_it_publishes_change_when_equatable_value_has_changed() {
        var didPublishWillSet = false
        var didPublishDidSet = false
        let observableObservationStore = ObservationStoreSpy()
        let observerObservationStore = ObservationStoreSpy()
        let observable = MockObservable()
        let sut = ObservableRegistrar(observationStore: observableObservationStore)
        sut.access(\.equatableObj, on: observable)
        XCTAssertNotNil(ThreadLocal.value)
        let entry = ThreadLocal.value?.entries.first?.value
        let willSetChangeHandler = AnyObservationChangeHandler { (_: MyEquatableType, _: MyEquatableType) in
            didPublishWillSet = true
        }
        let didSetChangeHandler = AnyObservationChangeHandler { (_: MyEquatableType, _: MyEquatableType) in
            didPublishDidSet = true
        }
        _ = entry?.addObserver(
            receiving: .willSet,
            changeHandler: willSetChangeHandler,
            observationStore: observerObservationStore
        )
        _ = entry?.addObserver(
            receiving: .didSet,
            changeHandler: didSetChangeHandler,
            observationStore: observerObservationStore
        )
        let oldValue = MyEquatableType("foo")
        let newValue = MyEquatableType("bar")
        sut.withMutation(of: \.equatableObj, on: observable, changingFrom: oldValue, to: newValue) {}
        XCTAssertTrue(didPublishWillSet)
        XCTAssertTrue(didPublishDidSet)
    }

    func test_it_skips_publishing_change_when_equatable_value_has_not_changed() {
        var didPublishWillSet = false
        var didPublishDidSet = false
        let observableObservationStore = ObservationStoreSpy()
        let observerObservationStore = ObservationStoreSpy()
        let observable = MockObservable()
        let sut = ObservableRegistrar(observationStore: observableObservationStore)
        sut.access(\.equatableObj, on: observable)
        XCTAssertNotNil(ThreadLocal.value)
        let entry = ThreadLocal.value?.entries.first?.value
        let willSetChangeHandler = AnyObservationChangeHandler { (_: MyEquatableType, _: MyEquatableType) in
            didPublishWillSet = true
        }
        let didSetChangeHandler = AnyObservationChangeHandler { (_: MyEquatableType, _: MyEquatableType) in
            didPublishDidSet = true
        }
        _ = entry?.addObserver(
            receiving: .willSet,
            changeHandler: willSetChangeHandler,
            observationStore: observerObservationStore
        )
        _ = entry?.addObserver(
            receiving: .didSet,
            changeHandler: didSetChangeHandler,
            observationStore: observerObservationStore
        )
        let oldValue = MyEquatableType("foo")
        let newValue = MyEquatableType("foo")
        sut.withMutation(of: \.equatableObj, on: observable, changingFrom: oldValue, to: newValue) {}
        XCTAssertFalse(didPublishWillSet)
        XCTAssertFalse(didPublishDidSet)
    }

    func test_it_always_publishes_change_for_non_equatable_types_even_when_they_have_not_changed() {
        var didPublishWillSet = false
        var didPublishDidSet = false
        let observableObservationStore = ObservationStoreSpy()
        let observerObservationStore = ObservationStoreSpy()
        let observable = MockObservable()
        let sut = ObservableRegistrar(observationStore: observableObservationStore)
        sut.access(\.nonEquatableObj, on: observable)
        XCTAssertNotNil(ThreadLocal.value)
        let entry = ThreadLocal.value?.entries.first?.value
        let willSetChangeHandler = AnyObservationChangeHandler { (_: MyNonEquatableType, _: MyNonEquatableType) in
            didPublishWillSet = true
        }
        let didSetChangeHandler = AnyObservationChangeHandler { (_: MyNonEquatableType, _: MyNonEquatableType) in
            didPublishDidSet = true
        }
        _ = entry?.addObserver(
            receiving: .willSet,
            changeHandler: willSetChangeHandler,
            observationStore: observerObservationStore
        )
        _ = entry?.addObserver(
            receiving: .didSet,
            changeHandler: didSetChangeHandler,
            observationStore: observerObservationStore
        )
        let oldValue = MyNonEquatableType("foo")
        let newValue = MyNonEquatableType("foo")
        sut.withMutation(of: \.nonEquatableObj, on: observable, changingFrom: oldValue, to: newValue) {}
        XCTAssertTrue(didPublishWillSet)
        XCTAssertTrue(didPublishDidSet)
    }
}
