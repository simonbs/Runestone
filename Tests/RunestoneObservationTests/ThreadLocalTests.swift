@testable import _RunestoneObservation
import XCTest

final class ThreadLocalTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ThreadLocal.value = nil
    }
    
    func test_it_stores_value() {
        XCTAssertNil(ThreadLocal.value)
        ThreadLocal.value = AccessList()
        XCTAssertNotNil(ThreadLocal.value)
    }
}
