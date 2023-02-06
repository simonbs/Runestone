import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    [
        testCase(RunestoneTests.allTests)
    ]
}
#endif
