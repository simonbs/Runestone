import Foundation
@testable import Runestone
import XCTest

/// Opt-in microbenchmarks. These measure line-index updates, excluding mutable
/// string storage, syntax highlighting, layout, and simulator frame delivery.
final class LineManagerPerformanceTests: XCTestCase {
    // swiftlint:disable:next function_body_length
    func testLargeDocumentLineIndexUpdates() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUNESTONE_PERFORMANCE"] == "1")
        let targetBytes = 25 * 1_024 * 1_024
        for lineLength in [120, 60_000] {
            let lineText = String(repeating: "a", count: lineLength - 1) + "\n"
            let text = String(repeating: lineText, count: (targetBytes + lineLength - 1) / lineLength)
            let stringView = StringView(string: text)
            let manager = LineManager(stringView: stringView)
            let start = DispatchTime.now().uptimeNanoseconds
            manager.rebuild()
            let rebuildMilliseconds = milliseconds(since: start)
            let initialLineCount = manager.lineCount
            let helper = TextEditHelper(stringView: stringView, lineManager: manager, lineEndings: .lf)
            print("LINE_INDEX fixture_bytes=\(text.utf8.count) line_length=\(lineLength) "
                  + "lines=\(initialLineCount) rebuild_ms=\(rebuildMilliseconds)")
            for (position, row) in [("start", 0), ("middle", initialLineCount / 2), ("end", initialLineCount - 2)] {
                for operation in ["character", "split", "join", "deleteLine"] {
                    var samples: [Double] = []
                    for iteration in 0..<32 {
                        let line = manager.line(atRow: row)
                        let range: NSRange
                        let replacement: String
                        switch operation {
                        case "character":
                            range = NSRange(location: line.location + lineLength / 2, length: 0)
                            replacement = "x"
                        case "split":
                            range = NSRange(location: line.location + lineLength / 2, length: 0)
                            replacement = "\n"
                        case "join":
                            range = NSRange(location: line.location + line.data.length, length: 1)
                            replacement = ""
                        default:
                            range = NSRange(location: line.location, length: line.data.totalLength)
                            replacement = ""
                        }
                        let removedText = stringView.substring(in: range) ?? ""
                        // The production index reads the already-mutated text.
                        // Keep storage movement out of this isolated measurement.
                        stringView.replaceText(in: range, with: replacement)
                        let start = DispatchTime.now().uptimeNanoseconds
                        let removed = manager.removeCharacters(in: range)
                        let inserted = manager.insert(replacement as NSString, at: range.location)
                        removed.union(with: inserted)
                        let elapsed = milliseconds(since: start)
                        if iteration >= 2 { samples.append(elapsed) }
                        let inverseRange = NSRange(location: range.location, length: replacement.utf16.count)
                        _ = helper.replaceText(in: inverseRange, with: removedText)
                        XCTAssertEqual(manager.lineCount, initialLineCount)
                        XCTAssertEqual(manager.lastLine.location, text.utf16.count)
                    }
                    samples.sort()
                    print("LINE_INDEX line_length=\(lineLength) position=\(position) operation=\(operation) "
                          + "samples=\(samples.count) median_ms=\(samples[samples.count / 2]) "
                          + "p95_ms=\(samples[Int(ceil(Double(samples.count) * 0.95)) - 1]) max_ms=\(samples.last!)")
                }
            }
        }
    }

    private func milliseconds(since start: UInt64) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }
}
