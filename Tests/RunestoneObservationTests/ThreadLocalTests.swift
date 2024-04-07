@testable import _RunestoneObservation
import XCTest

final class ThreadLocalTests: XCTestCase {
    func test_it_stores_value() {
        let initialPtr = ThreadLocal.value?.assumingMemoryBound(to: AccessList?.self)
        XCTAssertNil(initialPtr?.pointee)
        var accessList: AccessList?
        withUnsafeMutablePointer(to: &accessList) { ptr in
            ptr.pointee = AccessList()
            ThreadLocal.value = UnsafeMutableRawPointer(ptr)
        }
        XCTAssertNotNil(accessList)
        let sutPtr = ThreadLocal.value?.assumingMemoryBound(to: AccessList?.self)
        XCTAssertNotNil(sutPtr)
    }
}
