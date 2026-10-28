import XCTest

/// Plain ASCII documents exercise eligible layout paths without JSON wrappers.
@MainActor
final class PureASCIIEditorPerformanceTests: LargeFilePerformanceTestCase {
    func testUnbrokenWrapped() throws {
        try run(longLines: true, highlighted: false, wrapping: true, unbroken: true, purePlainText: true)
    }

    func testUnbrokenUnwrapped() throws {
        try run(longLines: true, highlighted: false, wrapping: false, unbroken: true, purePlainText: true)
    }

    func testWordsWrapped() throws {
        try run(longLines: true, highlighted: false, wrapping: true, purePlainText: true)
    }

    func testWordsUnwrapped() throws {
        try run(longLines: true, highlighted: false, wrapping: false, purePlainText: true)
    }
}
