import XCTest

/// Scrolling and editing benchmarks for short, long, and unbroken logical lines.
/// Run-loop callback intervals are recorded separately from synchronous layout.
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
