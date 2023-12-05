@testable import _RunestoneObservation
import XCTest

final class AnyObservationChangeHandlerTests: XCTestCase {
    func test_it_invokes_handler() throws {
        var didInvokeHandler = false
        let sut = AnyObservationChangeHandler { (_: String, _: String) in
            didInvokeHandler = true
        }
        try sut.invoke(changingFrom: "foo", to: "bar")
        XCTAssertTrue(didInvokeHandler)
    }

    func test_it_passes_values_to_handler() throws {
        var receivedOldValue: String?
        var receivedNewValue: String?
        let sut = AnyObservationChangeHandler { (oldValue: String, newValue: String) in
            receivedOldValue = oldValue
            receivedNewValue = newValue
        }
        try sut.invoke(changingFrom: "foo", to: "bar")
        XCTAssertEqual(receivedOldValue, "foo")
        XCTAssertEqual(receivedNewValue, "bar")
    }

    func test_it_throws_error_when_new_value_has_type_mismatch() throws {
        var didThrowError = false
        let sut = AnyObservationChangeHandler { (_: String, _: String) in }
        do {
            try sut.invoke(changingFrom: 42, to: "bar")
        } catch {
            didThrowError = true
        }
        XCTAssertTrue(didThrowError)
    }

    func test_it_throws_error_when_old_value_has_type_mismatch() throws {
        var didThrowError = false
        let sut = AnyObservationChangeHandler { (_: String, _: String) in }
        do {
            try sut.invoke(changingFrom: "foo", to: 42)
        } catch {
            didThrowError = true
        }
        XCTAssertTrue(didThrowError)
    }
}
