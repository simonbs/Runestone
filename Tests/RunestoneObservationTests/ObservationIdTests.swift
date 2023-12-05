@testable import _RunestoneObservation
import XCTest

final class ObservationIdTests: XCTestCase {
    func test_it_is_unique() {
        let id1 = ObservationId()
        let id2 = ObservationId()
        XCTAssertNotEqual(id1, id2)
    }
}
