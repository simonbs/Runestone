@testable import _RunestoneObservation
import XCTest

final class EquatableComparingChangeHandlerTests: XCTestCase {
    func test_it_passes_old_value_and_new_value_when_invoking_observer() throws {
        var receivedOldValue: String?
        var receivedNewValue: String?
        let sut = EquatableComparingChangeHandler(
            initialValue: "foo",
            tracker: { "bar" }
        ) { oldValue, newValue in
            receivedOldValue = oldValue
            receivedNewValue = newValue
        }
        try sut.invoke()
        XCTAssertEqual(receivedOldValue, "foo")
        XCTAssertEqual(receivedNewValue, "bar")
    }

    func test_it_publishes_change_when_equatable_value_has_changed() throws {
        var didPublish = false
        let sut = EquatableComparingChangeHandler(
            initialValue: MyEquatableType("foo"),
            tracker: { MyEquatableType("bar") }
        ) { _, _ in
            didPublish = true
        }
        try sut.invoke()
        XCTAssertTrue(didPublish)
    }

    func test_it_skips_publishing_change_when_equatable_value_has_not_changed() throws {
        var didPublish = false
        let sut = EquatableComparingChangeHandler(
            initialValue: MyEquatableType("foo"),
            tracker: { MyEquatableType("foo") }
        ) { _, _ in
            didPublish = true
        }
        try sut.invoke()
        XCTAssertFalse(didPublish)
    }
}
