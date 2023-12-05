@testable import _RunestoneObservation
import XCTest

final class ObservationTests: XCTestCase {
    func test_it_stores_handler() throws {
        var didCallHandler = false
        let observable = MockObservable()
        let observer = MockObserver()
        let propertyChangeId = PropertyChangeId(for: observable, publishing: .didSet, of: \.str)
        let sut = Observation(
            observer: observer,
            propertyChangeId: propertyChangeId
        ) { (_: String, _: String) in
            didCallHandler = true
        }
        try sut.handler.invoke(changingFrom: "foo", to: "bar")
        XCTAssertTrue(didCallHandler)
    }

    func test_it_invokes_cancel_on_observer() {
        let observable = MockObservable()
        let observer = MockObserver()
        let propertyChangeId = PropertyChangeId(for: observable, publishing: .didSet, of: \.str)
        let sut = Observation(
            observer: observer,
            propertyChangeId: propertyChangeId
        ) { (_: String, _: String) in }
        sut.invokeCancelOnObserver()
        XCTAssertTrue(observer.didCancel)
    }
}
