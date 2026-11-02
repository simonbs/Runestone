import Foundation
@testable import Runestone
import TestTreeSitterLanguages
import TreeSitter
import XCTest

/// Isolates parser/diff cost from layout. Run with RUNESTONE_PERFORMANCE=1.
final class TreeSitterIncrementalPerformanceTests: XCTestCase {
    func testFlatShortLineArray() throws { try run(lineLength: 128) }
    func testFlatLongLineArray() throws { try run(lineLength: 60_000) }

    // Keep parser setup, measured phases, and restoration together to preserve the benchmark timeline.
    // swiftlint:disable:next function_body_length
    private func run(lineLength: Int) throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUNESTONE_PERFORMANCE"] == "1")
        let payload = String(repeating: "a", count: lineLength - 6)
        let line = "  \"\(payload)\",\n"
        let count = (25 * 1_024 * 1_024 + lineLength - 1) / lineLength
        let original = "[\n" + String(repeating: line, count: count - 1) + "  \"\(payload)\"\n]\n"
        let location = 2 + (count / 2) * lineLength + 8
        let row = UInt32(count / 2 + 1)
        for resetParser in [false, true] {
            for retainSnapshot in [false, true] {
                for insertion in ["x", "\n"] {
                    let text = NSMutableString(string: original)
                    let delegate = IncrementalPerformanceTextProvider(text: text)
                    let parser = TreeSitterParser(encoding: .preferredUTF16)
                    parser.language = tree_sitter_json()
                    parser.delegate = delegate
                    var tree = try XCTUnwrap(parser.parse(text))
                    var samples: [String: [Double]] = [:]
                    for iteration in 0..<6 {
                        for undo in [false, true] {
                            let snapshot = retainSnapshot ? tree.copy() : nil
                            let oldEnd = undo ? location + 1 : location
                            let newEnd = undo ? location : location + 1
                            let pointBefore = TreeSitterTextPoint(row: row, column: 16)
                            let pointAfter = insertion == "\n"
                                ? TreeSitterTextPoint(row: row + 1, column: 0)
                                : TreeSitterTextPoint(row: row, column: 18)
                            text.replaceCharacters(in: NSRange(location: location, length: undo ? 1 : 0), with: undo ? "" : insertion)
                            let edit = TreeSitterInputEdit(
                                startByte: ByteCount(utf16Length: location),
                                oldEndByte: ByteCount(utf16Length: oldEnd),
                                newEndByte: ByteCount(utf16Length: newEnd),
                                startPoint: pointBefore,
                                oldEndPoint: undo ? pointAfter : pointBefore,
                                newEndPoint: undo ? pointBefore : pointAfter)
                            let editStart = DispatchTime.now().uptimeNanoseconds
                            tree.apply(edit)
                            let editTime = milliseconds(since: editStart)
                            let resetStart = DispatchTime.now().uptimeNanoseconds
                            if resetParser {
                                parser.language = tree_sitter_json()
                                parser.removeAllIncludedRanges()
                            }
                            let resetTime = milliseconds(since: resetStart)
                            delegate.readCount = 0
                            delegate.readBytes = 0
                            let parseStart = DispatchTime.now().uptimeNanoseconds
                            let nextTree = try XCTUnwrap(parser.parse(oldTree: tree))
                            let parseTime = milliseconds(since: parseStart)
                            let diffStart = DispatchTime.now().uptimeNanoseconds
                            let ranges = tree.rangesChanged(comparingTo: nextTree)
                            let diffTime = milliseconds(since: diffStart)
                            XCTAssertEqual(nextTree.rootNode.endByte, text.byteCount)
                            if undo { XCTAssertFalse(ts_node_has_error(nextTree.rootNode.rawValue)) }
                            if iteration > 0 {
                                let direction = undo ? "restore" : "insert"
                                for (metric, value) in [("edit", editTime), ("reset", resetTime), ("parse", parseTime), ("diff", diffTime),
                                                        ("readBytes", Double(delegate.readBytes)), ("reads", Double(delegate.readCount)),
                                                        ("changedRanges", Double(ranges.count))] {
                                    samples["\(direction)-\(metric)", default: []].append(value)
                                }
                            }
                            tree = nextTree
                            withExtendedLifetime(snapshot) {}
                        }
                    }
                    XCTAssertEqual(text as String, original)
                    for metric in samples.keys.sorted() {
                        let values = samples[metric]!.sorted()
                        print("TREE_INCREMENTAL line_length=\(lineLength) reset=\(resetParser) snapshot=\(retainSnapshot) "
                              + "insertion=\(insertion == "x" ? "character" : "newline") metric=\(metric) "
                              + "median=\(values[values.count / 2]) max=\(values.last!) count=\(values.count)")
                    }
                }
            }
        }
    }

    private func milliseconds(since start: UInt64) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
    }
}

private final class IncrementalPerformanceTextProvider: TreeSitterParserDelegate {
    let text: NSMutableString
    var readCount = 0
    var readBytes = 0

    init(text: NSMutableString) { self.text = text }

    func parser(_ parser: TreeSitterParser, bytesAt byteIndex: ByteCount) -> TreeSitterTextProviderResult? {
        guard byteIndex < text.byteCount else {
            return nil
        }
        let range = NSRange(location: byteIndex.utf16Length, length: min(2_048, text.length - byteIndex.utf16Length))
        var usedLength = 0
        guard let bytes = text.getBytes(in: range, encoding: String.preferredUTF16Encoding, usedLength: &usedLength) else {
            return nil
        }
        readCount += 1
        readBytes += usedLength
        return TreeSitterTextProviderResult(bytes: bytes, length: UInt32(usedLength))
    }
}
