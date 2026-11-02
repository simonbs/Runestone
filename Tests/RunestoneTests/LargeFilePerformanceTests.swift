import XCTest

/// Opt-in simulator benchmark. Run a Release build with testability enabled and
/// RUNESTONE_PERFORMANCE=1 in the test runner's environment. Select individual
/// cases with -only-testing; ordinary unit-test runs skip this expensive matrix.
///
/// Scroll intervals measure main-run-loop delivery, not compositor hitch time.
/// Edit samples include synchronous insertion/deletion and layout; queued async
/// highlighting can finish between samples and is not included in those samples.
@MainActor
final class LargeFilePerformanceTests: LargeFilePerformanceTestCase {
    func testShortLinesPlainWrapped() throws { try run(longLines: false, highlighted: false, wrapping: true) }
    func testShortLinesPlainUnwrapped() throws { try run(longLines: false, highlighted: false, wrapping: false) }
    func testLongLinesPlainWrapped() throws { try run(longLines: true, highlighted: false, wrapping: true) }
    func testLongLinesPlainUnwrapped() throws { try run(longLines: true, highlighted: false, wrapping: false) }
    func testShortLinesJSONWrapped() throws { try run(longLines: false, highlighted: true, wrapping: true) }
    func testShortLinesJSONUnwrapped() throws { try run(longLines: false, highlighted: true, wrapping: false) }
    func testLongLinesJSONWrapped() throws { try run(longLines: true, highlighted: true, wrapping: true) }
    func testLongLinesJSONUnwrapped() throws { try run(longLines: true, highlighted: true, wrapping: false) }

    func testLongUnbrokenPlainWrapped() throws {
        try run(longLines: true, highlighted: false, wrapping: true, unbroken: true)
    }

    func testLongUnbrokenPlainUnwrapped() throws {
        try run(longLines: true, highlighted: false, wrapping: false, unbroken: true)
    }

}
