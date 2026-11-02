import XCTest

/// The original matrix deliberately keeps its JSON-shaped fixtures. These opt-in
/// 25 MiB cases use the same interaction timeline with plain ASCII logical lines,
/// protecting the actual editor path for restricted line-layout optimizations.
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
