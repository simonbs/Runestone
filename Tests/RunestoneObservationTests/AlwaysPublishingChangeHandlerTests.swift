@testable import _RunestoneObservation
import XCTest

final class AlwaysPublishingChangeHandlerTests: XCTestCase {
    func test_it_passes_old_value_and_new_value_when_invoking_observer() throws {
        var receivedOldValue: String?
        var receivedNewValue: String?
        let sut = AlwaysPublishingChangeHandler(
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
        let sut = AlwaysPublishingChangeHandler(
            initialValue: MyEquatableType("foo"),
            tracker: { MyEquatableType("bar") }
        ) { _, _ in
            didPublish = true
        }
        try sut.invoke()
        XCTAssertTrue(didPublish)
    }

    func test_it_publishes_change_when_equatable_value_has_not_changed() throws {
        var didPublish = false
        let sut = AlwaysPublishingChangeHandler(
            initialValue: MyEquatableType("foo"),
            tracker: { MyEquatableType("foo") }
        ) { _, _ in
            didPublish = true
        }
        try sut.invoke()
        XCTAssertTrue(didPublish)
    }

    func test_it_publishes_change_for_non_equatable_values() throws {
        var didPublish = false
        let sut = AlwaysPublishingChangeHandler(
            initialValue: MyNonEquatableType("foo"),
            tracker: { MyNonEquatableType("bar") }
        ) { _, _ in
            didPublish = true
        }
        try sut.invoke()
        XCTAssertTrue(didPublish)
    }
}