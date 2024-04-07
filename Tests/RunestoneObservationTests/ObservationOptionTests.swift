@testable import _RunestoneObservation
import XCTest

final class ObservationOptionTests: XCTestCase {
    func test_it_creates_initial_value_option_from_raw_value() {
        let sut = ObservationOptions(rawValue: ObservationOptions.initialValue.rawValue)
        XCTAssertEqual(sut, .initialValue)
    }
}
