import Foundation
@testable import Runestone
import TestTreeSitterLanguages
import TreeSitter
import XCTest

// Keep the isolated prototype and its C callback lifetime helpers in the single experiment-owned file.
// swiftlint:disable file_length

/// Test-only prototype. The parser is confined to one serial caller; only the cancellation token is shared.
/// Large cases require RUNESTONE_PERFORMANCE=1. They report samples without imposing device-specific latency limits.
final class ParserCancellationExperimentTests: XCTestCase {
    func testCancellationBeforeStartAndAfterCompletion() throws {
        let parser = try CancellationExperimentParser()
        let input = CancellationExperimentInput("[\"Grøn 😀\", 42, true, null]")
        let before = CancellationExperimentToken()
        before.cancel()
        XCTAssertNil(parser.parse(input, token: before))
        XCTAssertEqual(before.statistics.callbacks, 0)

        let after = CancellationExperimentToken()
        let tree = try XCTUnwrap(parser.parse(input, token: after))
        after.cancel()
        try assertMatchesFresh(tree, input: input)
        let replacement = CancellationExperimentInput("{\"replacement\": [false, \"🧑‍💻\"]}")
        try assertMatchesFresh(XCTUnwrap(parser.parse(replacement)), input: replacement)
        // Cancellation of a completed request cannot mutate the returned tree.
        try assertMatchesFresh(tree, input: input)
    }

    func testCancellationDuringParseThenResetMatchesFreshParse() throws {
        let parser = try CancellationExperimentParser()
        for lineLength in [128, 60_000] {
            let input = CancellationExperimentInput(makeFixture(lineLength: lineLength, minimumBytes: 512 * 1_024))
            let token = CancellationExperimentToken(cancelAtByte: UInt32(input.units.count / 2))
            XCTAssertNil(parser.parse(input, token: token))
            XCTAssertNotNil(token.statistics.observedAt)
            let replacement = CancellationExperimentInput("[42, \"Grøn 😀\", false]")
            try assertMatchesFresh(XCTUnwrap(parser.parse(replacement)), input: replacement)
            try assertMatchesFresh(XCTUnwrap(parser.parse(input)), input: input)
        }
    }

    func testRepeatedReplacementPreservesRetainedSnapshotAndIncrementalReparse() throws {
        let parser = try CancellationExperimentParser()
        let original = CancellationExperimentInput("[\"Grøn 😀\", 42, true, null]")
        let originalTree = try XCTUnwrap(parser.parse(original))
        let retainedTree = originalTree.copy()
        let query = try TreeSitterQuery(source: "((number) @number (#eq? @number \"42\"))", language: tree_sitter_json())
        let snapshot = TreeSitterHighlightSnapshot(
            layers: [.init(tree: originalTree.copy(), query: query)], stringView: StringView(string: original.text))
        let expectedCaptures = captureValues(tree: retainedTree, query: query, text: original.text)
        XCTAssertEqual(expectedCaptures.map(\.range), [ByteRange(utf16Range: (original.text as NSString).range(of: "42"))])
        var previousInput = original
        var previousTree = originalTree
        for iteration in 0..<6 {
            // Alternate valid/error-bearing replacements to catch leaked parser recovery state as well as stale text.
            let suffix = iteration.isMultiple(of: 2) ? "\n" : "\n[\"unterminated"
            let input = CancellationExperimentInput(makeFixture(lineLength: 128, minimumBytes: 64 * 1_024) + suffix)
            let editedTree = previousTree.copy()
            editedTree.apply(TreeSitterInputEdit(
                startByte: 0, oldEndByte: ByteCount(previousInput.units.count * 2), newEndByte: ByteCount(input.units.count * 2),
                startPoint: TreeSitterTextPoint(row: 0, column: 0),
                oldEndPoint: endPoint(previousInput.text), newEndPoint: endPoint(input.text)))
            let token = CancellationExperimentToken(cancelAtByte: 0)
            XCTAssertNil(parser.parse(input, oldTree: editedTree, token: token))
            XCTAssertNotNil(token.statistics.observedAt)
            let reparsed = try XCTUnwrap(parser.parse(input, oldTree: editedTree))
            let fresh = try freshTree(input)
            try assertMatchesFresh(reparsed, input: input, fresh: fresh)
            XCTAssertEqual(rangeValues(editedTree.rangesChanged(comparingTo: reparsed)),
                           rangeValues(editedTree.rangesChanged(comparingTo: fresh)))
            try assertMatchesFresh(retainedTree, input: original)
            let captures = snapshot.captures(in: retainedTree.rootNode.byteRange)
            XCTAssertEqual(captures.map(CancellationExperimentCapture.init), expectedCaptures)
            previousTree = reparsed
            previousInput = input
        }
    }

    func testShortJSON25MiBCancellationResponsiveness() throws { try measureCancellation(lineLength: 128) }
    func testLongJSON25MiBCancellationResponsiveness() throws { try measureCancellation(lineLength: 60_000) }

    // Keep timing phases together so clock boundaries remain explicit.
    // swiftlint:disable:next function_body_length
    private func measureCancellation(lineLength: Int) throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUNESTONE_PERFORMANCE"] == "1")
        let preparationStart = DispatchTime.now().uptimeNanoseconds
        let input = CancellationExperimentInput(makeFixture(lineLength: lineLength, minimumBytes: 25 * 1_024 * 1_024))
        let preparationMS = elapsed(since: preparationStart)
        let parser = try CancellationExperimentParser()
        let queue = DispatchQueue(label: "Runestone.ParserCancellationExperiment")
        for sample in 0..<5 {
            let token = CancellationExperimentToken()
            let result = CancellationExperimentResult()
            let done = expectation(description: "Native parse stopped and reset")
            queue.async {
                let start = DispatchTime.now().uptimeNanoseconds
                let tree = parser.parse(input, token: token)
                result.store(tree: tree, elapsedMS: self.elapsed(since: start))
                done.fulfill()
            }
            // Wait for real native progress, then cancel from another thread. No callback is paused for the measurement.
            let started = token.started.wait(timeout: .now() + 30)
            // Include some useful work before superseding the request; this is outside the cancellation-latency interval.
            if started == .success { Thread.sleep(forTimeInterval: 0.005) }
            token.cancel()
            wait(for: [done], timeout: 60)
            XCTAssertEqual(started, .success)
            let statistics = token.statistics
            let outcome = result.value
            XCTAssertTrue(outcome.finished, "Do not reuse a parser while its native call is still running.")
            guard outcome.finished else {
                return
            }
            XCTAssertNil(outcome.tree, "The request must be canceled during parsing, not after it finishes.")
            let requested = try XCTUnwrap(statistics.requestedAt)
            let observed = try XCTUnwrap(statistics.observedAt)
            let returned = try XCTUnwrap(statistics.returnedAt)
            let reset = try XCTUnwrap(statistics.resetAt)
            print("PARSER_CANCELLATION line_length=\(lineLength) sample=\(sample) utf8_bytes=\(input.text.utf8.count) "
                  + "utf16_bytes=\(input.units.count * 2) preparation_ms=\(preparationMS) parse_total_ms=\(outcome.elapsedMS) "
                  + "request_to_callback_ms=\(milliseconds(observed - requested)) "
                  + "request_to_return_ms=\(milliseconds(returned - requested)) "
                  + "request_to_reset_ms=\(milliseconds(reset - requested)) callbacks=\(statistics.callbacks) "
                  + "observed_byte=\(statistics.observedByte)")
            // A different input must start cleanly after every cancellation, on the same native parser.
            let replacement = CancellationExperimentInput("{\"revision\": \(sample), \"Grøn 😀\": [null, false]}")
            try assertMatchesFresh(XCTUnwrap(parser.parse(replacement)), input: replacement)
        }
        // Cancel after substantial progress too: reset/reparse the entire large document and compare all nodes/captures.
        let late = CancellationExperimentToken(cancelAtByte: UInt32(input.units.count))
        XCTAssertNil(parser.parse(input, token: late))
        XCTAssertNotNil(late.statistics.observedAt)
        let lateRequest = try XCTUnwrap(late.statistics.requestedAt)
        let lateReset = try XCTUnwrap(late.statistics.resetAt)
        print("PARSER_CANCELLATION_LATE line_length=\(lineLength) observed_byte=\(late.statistics.observedByte) "
              + "callback_to_reset_ms=\(milliseconds(lateReset - lateRequest))")
        let reparseStart = DispatchTime.now().uptimeNanoseconds
        let reparsed = try XCTUnwrap(parser.parse(input))
        let reparseMS = elapsed(since: reparseStart)
        let freshStart = DispatchTime.now().uptimeNanoseconds
        let fresh = try freshTree(input)
        let freshMS = elapsed(since: freshStart)
        try assertMatchesFresh(reparsed, input: input, fresh: fresh)
        print("PARSER_CANCELLATION_RECOVERY line_length=\(lineLength) reparse_ms=\(reparseMS) fresh_production_ms=\(freshMS)")
    }

    private func makeFixture(lineLength: Int, minimumBytes: Int) -> String {
        let payload = String(repeating: "a", count: lineLength - 6)
        let count = max(2, (minimumBytes + lineLength - 1) / lineLength)
        return "[\n" + String(repeating: "  \"\(payload)\",\n", count: count - 1) + "  \"\(payload)\"\n]\n"
    }

    private func makeQuery() throws -> TreeSitterQuery {
        try TreeSitterQuery(source: "(string) @string (number) @number (true) @constant (false) @constant (null) @constant",
                            language: tree_sitter_json())
    }

    private func freshTree(_ input: CancellationExperimentInput) throws -> TreeSitterTree {
        let parser = TreeSitterParser(encoding: .preferredUTF16)
        parser.language = tree_sitter_json()
        return try XCTUnwrap(parser.parse(input.text as NSString))
    }

    private func assertMatchesFresh(_ tree: TreeSitterTree, input: CancellationExperimentInput,
                                    fresh: TreeSitterTree? = nil, file: StaticString = #filePath, line: UInt = #line) throws {
        let expected = try fresh ?? freshTree(input)
        assertNodesEqual(tree, expected, file: file, line: line)
        let query = try makeQuery()
        XCTAssertEqual(captureValues(tree: tree, query: query, text: input.text),
                       captureValues(tree: expected, query: query, text: input.text), file: file, line: line)
    }

    private func captureValues(tree: TreeSitterTree, query: TreeSitterQuery, text: String) -> [CancellationExperimentCapture] {
        let cursor = TreeSitterQueryCursor(query: query, node: tree.rootNode)
        cursor.execute()
        return cursor.validCaptures(in: StringView(string: text)).map(CancellationExperimentCapture.init)
    }

    private func rangeValues(_ ranges: [TreeSitterTextRange]) -> [[UInt32]] {
        ranges.map { range in
            [UInt32(range.startByte.value), UInt32(range.endByte.value), range.startPoint.row, range.startPoint.column,
             range.endPoint.row, range.endPoint.column]
        }
    }

    private func endPoint(_ text: String) -> TreeSitterTextPoint {
        let lines = text.components(separatedBy: "\n")
        return TreeSitterTextPoint(row: UInt32(lines.count - 1), column: UInt32(lines.last!.utf16.count * 2))
    }

    // Streaming cursor traversal avoids materializing megabytes of S-expressions and quadratic flat-array child lookups.
    private func assertNodesEqual(_ actual: TreeSitterTree, _ expected: TreeSitterTree,
                                  file: StaticString, line: UInt) {
        var left = ts_tree_cursor_new(actual.rootNode.rawValue)
        var right = ts_tree_cursor_new(expected.rootNode.rawValue)
        defer { ts_tree_cursor_delete(&left); ts_tree_cursor_delete(&right) }
        repeat {
            let leftValue = CancellationExperimentNode(ts_tree_cursor_current_node(&left))
            let rightValue = CancellationExperimentNode(ts_tree_cursor_current_node(&right))
            guard leftValue == rightValue,
                  ts_tree_cursor_current_field_id(&left) == ts_tree_cursor_current_field_id(&right) else {
                XCTFail("Reset/reparse differs from fresh parse at byte \(leftValue.startByte)", file: file, line: line)
                return
            }
            let leftMoves = advance(&left)
            let rightMoves = advance(&right)
            guard leftMoves == rightMoves else {
                XCTFail("Tree structure differs", file: file, line: line)
                return
            }
            if !leftMoves {
                return
            }
        } while true
    }

    private func advance(_ cursor: inout TSTreeCursor) -> Bool {
        if ts_tree_cursor_goto_first_child(&cursor) {
            return true
        }
        while !ts_tree_cursor_goto_next_sibling(&cursor) {
            if !ts_tree_cursor_goto_parent(&cursor) {
                return false
            }
        }
        return true
    }

    private func elapsed(since start: UInt64) -> Double { milliseconds(DispatchTime.now().uptimeNanoseconds - start) }
    private func milliseconds(_ nanoseconds: UInt64) -> Double { Double(nanoseconds) / 1_000_000 }
}

private struct CancellationExperimentInput {
    let text: String
    let units: [UInt16]

    init(_ text: String) {
        self.text = text
        self.units = Array(text.utf16)
    }
}

private final class CancellationExperimentParser {
    private let pointer: OpaquePointer

    init() throws {
        pointer = try XCTUnwrap(ts_parser_new())
        XCTAssertTrue(ts_parser_set_language(pointer, tree_sitter_json()))
    }

    deinit { ts_parser_delete(pointer) }

    func parse(_ input: CancellationExperimentInput, oldTree: TreeSitterTree? = nil,
               token: CancellationExperimentToken = CancellationExperimentToken()) -> TreeSitterTree? {
        guard !token.isCancelled else {
            return nil
        }
        return input.units.withUnsafeBytes { bytes in
            let context = CancellationExperimentContext(bytes: bytes, token: token)
            let payload = Unmanaged.passUnretained(context).toOpaque()
            // Both borrowed pointers and context remain alive through native return AND reset. No mutable editor reads.
            return withExtendedLifetime((context, oldTree)) {
                let nativeInput = TSInput(payload: payload, read: cancellationExperimentRead, encoding: .preferredUTF16, decode: nil)
                let options = TSParseOptions(payload: payload, progress_callback: cancellationExperimentProgress)
                let tree = ts_parser_parse_with_options(pointer, oldTree?.pointer, nativeInput, options)
                token.didReturn()
                if tree == nil {
                    ts_parser_reset(pointer)
                    token.didReset()
                }
                // Handles a request arriving after the final native callback but before this result is published.
                guard !token.isCancelled else {
                    if let tree = tree { ts_tree_delete(tree) }
                    return nil
                }
                return tree.map(TreeSitterTree.init)
            }
        }
    }
}

private final class CancellationExperimentContext {
    let bytes: UnsafeRawBufferPointer
    let token: CancellationExperimentToken

    init(bytes: UnsafeRawBufferPointer, token: CancellationExperimentToken) {
        self.bytes = bytes
        self.token = token
    }
}

private func cancellationExperimentRead(_ payload: UnsafeMutableRawPointer?, _ byteIndex: UInt32,
                                        _ point: TSPoint, _ bytesRead: UnsafeMutablePointer<UInt32>?) -> UnsafePointer<Int8>? {
    let context = Unmanaged<CancellationExperimentContext>.fromOpaque(payload!).takeUnretainedValue()
    let remaining = context.bytes.count - Int(byteIndex)
    guard remaining > 0 else {
        bytesRead?.pointee = 0
        return nil
    }
    bytesRead?.pointee = UInt32(min(4_096, remaining))
    return context.bytes.baseAddress!.advanced(by: Int(byteIndex)).assumingMemoryBound(to: Int8.self)
}

private func cancellationExperimentProgress(_ state: UnsafeMutablePointer<TSParseState>?) -> Bool {
    let state = state!.pointee
    let context = Unmanaged<CancellationExperimentContext>.fromOpaque(state.payload!).takeUnretainedValue()
    return context.token.progress(byte: state.current_byte_offset)
}

private final class CancellationExperimentToken {
    struct Statistics {
        var callbacks = 0
        var requestedAt: UInt64?
        var observedAt: UInt64?
        var returnedAt: UInt64?
        var resetAt: UInt64?
        var observedByte: UInt32 = 0
    }

    let started = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private let cancelAtByte: UInt32?
    private var state = Statistics()
    var statistics: Statistics { lock.lock(); defer { lock.unlock() }; return state }
    var isCancelled: Bool { statistics.requestedAt != nil }

    init(cancelAtByte: UInt32? = nil) { self.cancelAtByte = cancelAtByte }

    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        if state.requestedAt == nil { state.requestedAt = DispatchTime.now().uptimeNanoseconds }
    }

    func progress(byte: UInt32) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        state.callbacks += 1
        if state.callbacks == 1 { started.signal() }
        if let threshold = cancelAtByte, byte >= threshold, state.requestedAt == nil {
            state.requestedAt = DispatchTime.now().uptimeNanoseconds
        }
        if state.requestedAt != nil {
            state.observedAt = DispatchTime.now().uptimeNanoseconds
            state.observedByte = byte
            return true
        }
        return false
    }

    func didReturn() {
        lock.lock()
        defer { lock.unlock() }
        state.returnedAt = DispatchTime.now().uptimeNanoseconds
    }

    func didReset() {
        lock.lock()
        defer { lock.unlock() }
        state.resetAt = DispatchTime.now().uptimeNanoseconds
    }
}

private final class CancellationExperimentResult {
    struct Value {
        var finished = false
        var tree: TreeSitterTree?
        var elapsedMS = 0.0
    }
    private let lock = NSLock()
    private var stored = Value()
    var value: Value { lock.lock(); defer { lock.unlock() }; return stored }

    func store(tree: TreeSitterTree?, elapsedMS: Double) {
        lock.lock()
        defer { lock.unlock() }
        stored = Value(finished: true, tree: tree, elapsedMS: elapsedMS)
    }
}

private struct CancellationExperimentCapture: Equatable {
    let name: String
    let range: ByteRange
    let node: CancellationExperimentNode

    init(_ capture: TreeSitterCapture) {
        name = capture.name
        range = capture.byteRange
        node = CancellationExperimentNode(capture.node.rawValue)
    }
}

private struct CancellationExperimentNode: Equatable {
    let symbol: UInt16
    let startByte: UInt32
    let endByte: UInt32
    let startRow: UInt32
    let startColumn: UInt32
    let endRow: UInt32
    let endColumn: UInt32
    let childCount: UInt32
    let isNamed: Bool
    let isMissing: Bool
    let hasError: Bool

    init(_ node: TSNode) {
        symbol = ts_node_symbol(node)
        startByte = ts_node_start_byte(node)
        endByte = ts_node_end_byte(node)
        let start = ts_node_start_point(node)
        let end = ts_node_end_point(node)
        startRow = start.row
        startColumn = start.column
        endRow = end.row
        endColumn = end.column
        childCount = ts_node_child_count(node)
        isNamed = ts_node_is_named(node)
        isMissing = ts_node_is_missing(node)
        hasError = ts_node_has_error(node)
    }
}
