#if canImport(AppKit)
import AppKit
import Darwin
@testable import RunestoneAppKit
import RunestoneEngine
import RunestoneSyntax
import TestTreeSitterLanguages
import XCTest

/// Opt-in Release measurements for the AppKit/Core Text document surface.
///
/// These results are machine-specific baselines, not pass/fail budgets. Fixture
/// Fixture construction is outside the samples. View load includes the
/// attributed-snapshot copy, line indexing and first viewport layout. Separate
/// syntax scenarios measure real Tree-sitter parse, bounded capture and fold
/// queries, incremental reuse and cancellation.
@MainActor
final class NativeMacPerformanceBaselineTests: XCTestCase {
    private let viewport = NSSize(width: 700, height: 480)
    private let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    func testRepresentativeAppKitScenarios() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUNESTONE_MAC_PERFORMANCE"] == "1",
                          "Set RUNESTONE_MAC_PERFORMANCE=1 for opt-in Release measurements.")

        let requestedScenario = ProcessInfo.processInfo.environment["RUNESTONE_MAC_PERFORMANCE_SCENARIO"]
        let scenarios = makeScenarios().filter { requestedScenario == nil || $0.name == requestedScenario }
        if scenarios.isEmpty { throw XCTSkip("Requested scenario belongs to another performance lane.") }
        for scenario in scenarios {
            var trials: [Trial] = []
            for trialIndex in 0..<4 {
                let trial = measure(scenario)
                XCTAssertGreaterThan(trial.documentHeight, 0)
                XCTAssertGreaterThan(trial.visibleUTF16Length, 0)
                if trialIndex > 0 { trials.append(trial) } // discard cold process/framework setup
            }
            report(scenario, trials: trials)
        }
    }

    func testRepresentativeSyntaxScenarios() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUNESTONE_MAC_PERFORMANCE"] == "1",
                          "Set RUNESTONE_MAC_PERFORMANCE=1 for opt-in Release measurements.")

        let requestedScenario = ProcessInfo.processInfo.environment["RUNESTONE_MAC_PERFORMANCE_SCENARIO"]
        let scenarios = makeSyntaxScenarios().filter { requestedScenario == nil || $0.name == requestedScenario }
        if scenarios.isEmpty { throw XCTSkip("Requested scenario belongs to another performance lane.") }
        for scenario in scenarios {
            var trials: [SyntaxTrial] = []
            for trialIndex in 0..<4 {
                let trial = try measureSyntax(scenario)
                XCTAssertGreaterThan(trial.utf16Length, 0)
                if trialIndex > 0 { trials.append(trial) }
            }
            reportSyntax(scenario, trials: trials)
        }

        if requestedScenario == nil || requestedScenario == "syntax-cancellation-10mb" {
            var samples: [Double] = []
            for trialIndex in 0..<4 {
                let milliseconds = try measureSyntaxCancellation()
                if trialIndex > 0 { samples.append(milliseconds) }
            }
            reportSyntaxCancellation(samples)
        }
    }

    private func measure(_ scenario: Scenario) -> Trial {
        autoreleasepool {
            let content = scenario.makeContent()
            let residentBefore = residentBytes()
            let loadStart = ProcessInfo.processInfo.systemUptime
            let view = ReadOnlyDocumentView(content: content)
            let scrollView = NSScrollView(frame: NSRect(origin: .zero, size: viewport))
            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = false
            scrollView.documentView = view
            scrollView.tile()
            scenario.configure(view)
            view.updateViewport()
            view.layoutSubtreeIfNeeded()
            let loadMilliseconds = elapsedMilliseconds(since: loadStart)
            let residentAfterLoad = residentBytes()

            let traversalStart = ProcessInfo.processInfo.systemUptime
            let maximumY = max(0, view.frame.height - scrollView.contentView.bounds.height)
            for fraction in [0.5, 1.0, 0.0, 1.0] {
                scrollView.contentView.scroll(to: NSPoint(x: 0, y: maximumY * fraction))
                scrollView.reflectScrolledClipView(scrollView.contentView)
                view.layoutSubtreeIfNeeded()
            }
            let traversalMilliseconds = elapsedMilliseconds(since: traversalStart)
            let residentAfterTraversal = residentBytes()
            let visibleLength = view.visibleLayout?.lines.reduce(0) { partial, line in
                partial + line.line.data.totalLength
            } ?? 0
            let residentObservation = max(residentAfterLoad, residentAfterTraversal)
            if scenario.isFolded {
                XCTAssertTrue(view.manager.isLineHidden(1))
                XCTAssertLessThan(view.frame.height, CGFloat(view.manager.lineCount) * 16)
            }
            return Trial(loadMilliseconds: loadMilliseconds,
                         traversalMilliseconds: traversalMilliseconds,
                         residentDeltaBytes: residentObservation >= residentBefore ? residentObservation - residentBefore : 0,
                         residentObservationBytes: residentObservation,
                         utf8Bytes: content.string.utf8.count,
                         utf16Length: content.length,
                         logicalLines: content.string.reduce(into: 1) { $0 += $1 == "\n" ? 1 : 0 },
                         documentHeight: view.frame.height,
                         visibleUTF16Length: visibleLength)
        }
    }

    private func makeScenarios() -> [Scenario] {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.textColor
        ]
        let shortLine = "let value = 12345 // representative source line\n"
        return [
            Scenario(name: "small-200-lines") {
                NSAttributedString(string: String(repeating: shortLine, count: 200), attributes: attributes)
            },
            Scenario(name: "large-10mb-short-lines") { [self] in
                NSAttributedString(string: makeExactUTF8Fixture(byteCount: 10_000_000), attributes: attributes)
            },
            Scenario(name: "wrapped-1mib-single-line") {
                NSAttributedString(string: String(repeating: "alpha beta gamma delta ", count: 47_663), attributes: attributes)
            },
            Scenario(name: "highlighted-20000-lines") {
                let result = NSMutableAttributedString(string: String(repeating: shortLine, count: 20_000), attributes: attributes)
                let source = result.string as NSString
                var searchRange = NSRange(location: 0, length: source.length)
                while searchRange.length > 0 {
                    let match = source.range(of: "12345", options: [], range: searchRange)
                    if match.location == NSNotFound { break }
                    result.addAttribute(.foregroundColor, value: NSColor.systemPurple, range: match)
                    searchRange = NSRange(location: NSMaxRange(match), length: source.length - NSMaxRange(match))
                }
                return result
            },
            Scenario(name: "folded-20000-lines", isFolded: true, makeContent: {
                NSAttributedString(string: String(repeating: shortLine, count: 20_000), attributes: attributes)
            }) { view in
                view.manager.setCollapsedLineRanges([1...18_000])
            }
        ]
    }

    private func makeSyntaxScenarios() -> [SyntaxScenario] {
        let shortLine = "const value = 12345; // representative source line\n"
        return [
            SyntaxScenario(name: "syntax-small-200-lines", text: String(repeating: shortLine, count: 200)),
            SyntaxScenario(name: "syntax-large-10mb-short-lines",
                           text: makeExactASCIIFixture(line: shortLine, byteCount: 10_000_000)),
            SyntaxScenario(name: "syntax-wrapped-1mib-single-line",
                           text: "const value = " + String(repeating: "alpha + ", count: 137_000) + "0;",
                           expectsVisibleCaptures: false),
            SyntaxScenario(name: "syntax-highlighted-20000-lines",
                           text: String(repeating: shortLine, count: 20_000)),
            SyntaxScenario(name: "syntax-folded-20000-functions",
                           text: (0..<20_000).map { "function f\($0)() { return \($0); }\n" }.joined(),
                           queryFolds: true),
            SyntaxScenario(name: "syntax-incremental-20000-lines",
                           text: String(repeating: shortLine, count: 20_000), measuresIncrementalEdit: true)
        ]
    }

    private func measureSyntax(_ scenario: SyntaxScenario) throws -> SyntaxTrial {
        let highlighter = try makeJavaScriptHighlighter()
        let residentBefore = residentBytes()
        let parseStart = ProcessInfo.processInfo.systemUptime
        try waitForUpdate(highlighter, text: scenario.text)
        let parseMilliseconds = elapsedMilliseconds(since: parseStart)
        let residentAfterParse = residentBytes()

        let captureStart = ProcessInfo.processInfo.systemUptime
        let captureLength = min((scenario.text as NSString).length, 65_536)
        let captures = try waitForCaptures(highlighter, range: NSRange(location: 0, length: captureLength))
        let captureMilliseconds = elapsedMilliseconds(since: captureStart)

        let foldStart = ProcessInfo.processInfo.systemUptime
        let folds = try waitForFolds(highlighter)
        let foldMilliseconds = elapsedMilliseconds(since: foldStart)

        var incrementalMilliseconds: Double?
        if scenario.measuresIncrementalEdit {
            let source = NSMutableString(string: scenario.text)
            let location = source.length / 2
            source.replaceCharacters(in: NSRange(location: location, length: 1), with: "9")
            let editStart = ProcessInfo.processInfo.systemUptime
            try waitForUpdate(highlighter, text: source as String)
            incrementalMilliseconds = elapsedMilliseconds(since: editStart)
        }
        let residentObservation = max(residentAfterParse, residentBytes())
        if scenario.queryFolds { XCTAssertGreaterThan(folds.count, 10_000) }
        if scenario.expectsVisibleCaptures { XCTAssertFalse(captures.isEmpty) }
        return SyntaxTrial(parseMilliseconds: parseMilliseconds,
                           captureMilliseconds: captureMilliseconds,
                           foldMilliseconds: foldMilliseconds,
                           incrementalMilliseconds: incrementalMilliseconds,
                           residentDeltaBytes: residentObservation >= residentBefore ? residentObservation - residentBefore : 0,
                           residentObservationBytes: residentObservation,
                           utf8Bytes: scenario.text.utf8.count,
                           utf16Length: (scenario.text as NSString).length,
                           captureCount: captures.count,
                           foldCount: folds.count)
    }

    private func measureSyntaxCancellation() throws -> Double {
        let highlighter = try makeJavaScriptHighlighter()
        let large = makeExactASCIIFixture(
            line: "const value = 12345; // cancellation fixture\n", byteCount: 10_000_000)
        let first = expectation(description: "superseded parse cancelled")
        let second = expectation(description: "newest parse published")
        let start = ProcessInfo.processInfo.systemUptime
        highlighter.update(large) { result in
            if case .failure(.cancelled) = result { first.fulfill() }
        }
        highlighter.update("const newest = 42;\n") { result in
            if case .success = result { second.fulfill() }
        }
        wait(for: [first, second], timeout: 30)
        return elapsedMilliseconds(since: start)
    }

    private func makeJavaScriptHighlighter() throws -> RunestoneSyntaxHighlighter {
        try RunestoneSyntaxHighlighter(language: RunestoneSyntaxLanguage(
            language: tree_sitter_javascript(),
            highlightsQuery: """
            (number) @number
            (string) @string
            (comment) @comment
            """,
            foldsQuery: "(statement_block) @fold"))
    }

    private func waitForUpdate(_ highlighter: RunestoneSyntaxHighlighter, text: String) throws {
        let finished = expectation(description: "syntax update")
        let box = LockedResultBox<Void>()
        highlighter.update(text) { result in box.set(result); finished.fulfill() }
        wait(for: [finished], timeout: 60)
        _ = try XCTUnwrap(box.value).get()
    }

    private func waitForCaptures(_ highlighter: RunestoneSyntaxHighlighter,
                                 range: NSRange) throws -> [RunestoneSyntaxCapture] {
        let finished = expectation(description: "syntax captures")
        let box = LockedResultBox<[RunestoneSyntaxCapture]>()
        highlighter.captures(in: range) { result in box.set(result); finished.fulfill() }
        wait(for: [finished], timeout: 60)
        return try XCTUnwrap(box.value).get()
    }

    private func waitForFolds(_ highlighter: RunestoneSyntaxHighlighter) throws -> [RunestoneSyntaxFold] {
        let finished = expectation(description: "syntax folds")
        let box = LockedResultBox<[RunestoneSyntaxFold]>()
        highlighter.folds { result in box.set(result); finished.fulfill() }
        wait(for: [finished], timeout: 60)
        return try XCTUnwrap(box.value).get()
    }

    private func makeExactASCIIFixture(line: String, byteCount: Int) -> String {
        precondition(line.utf8.count == line.count)
        let repetitions = byteCount / line.count
        let remainder = byteCount - repetitions * line.count
        return String(repeating: line, count: repetitions) + String(repeating: " ", count: remainder)
    }

    private func makeExactUTF8Fixture(byteCount: Int) -> String {
        let line = String(repeating: "a", count: 999) + "\n"
        precondition(byteCount.isMultiple(of: line.utf8.count))
        return String(repeating: line, count: byteCount / line.utf8.count)
    }

    private func report(_ scenario: Scenario, trials: [Trial]) {
        let load = trials.map(\.loadMilliseconds)
        let traversal = trials.map(\.traversalMilliseconds)
        let memory = trials.map(\.residentDeltaBytes)
        let result: [String: Any] = [
            "scenario": scenario.name,
            "utf8Bytes": trials.last?.utf8Bytes ?? 0,
            "utf16Length": trials.last?.utf16Length ?? 0,
            "logicalLines": trials.last?.logicalLines ?? 0,
            "loadSamplesMs": load,
            "loadMedianMs": median(load),
            "traversalSamplesMs": traversal,
            "traversalMedianMs": median(traversal),
            "residentDeltaSamplesBytes": memory,
            "residentDeltaMedianBytes": median(memory),
            "residentObservationSamplesBytes": trials.map(\.residentObservationBytes),
            "residentObservationMedianBytes": median(trials.map(\.residentObservationBytes)),
            "documentHeight": trials.last?.documentHeight ?? 0,
            "finalVisibleUTF16Length": trials.last?.visibleUTF16Length ?? 0
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            XCTFail("Unable to serialize Mac performance result for \(scenario.name)")
            return
        }
        print("RUNESTONE_MAC_PERFORMANCE_RESULT \(json)")
    }

    private func reportSyntax(_ scenario: SyntaxScenario, trials: [SyntaxTrial]) {
        let result: [String: Any] = [
            "scenario": scenario.name,
            "utf8Bytes": trials.last?.utf8Bytes ?? 0,
            "utf16Length": trials.last?.utf16Length ?? 0,
            "parseSamplesMs": trials.map(\.parseMilliseconds),
            "parseMedianMs": median(trials.map(\.parseMilliseconds)),
            "captureSamplesMs": trials.map(\.captureMilliseconds),
            "captureMedianMs": median(trials.map(\.captureMilliseconds)),
            "foldSamplesMs": trials.map(\.foldMilliseconds),
            "foldMedianMs": median(trials.map(\.foldMilliseconds)),
            "incrementalSamplesMs": trials.compactMap(\.incrementalMilliseconds),
            "captureCount": trials.last?.captureCount ?? 0,
            "foldCount": trials.last?.foldCount ?? 0,
            "residentDeltaSamplesBytes": trials.map(\.residentDeltaBytes),
            "residentDeltaMedianBytes": median(trials.map(\.residentDeltaBytes)),
            "residentObservationSamplesBytes": trials.map(\.residentObservationBytes),
            "residentObservationMedianBytes": median(trials.map(\.residentObservationBytes))
        ]
        reportJSON(result, scenario: scenario.name)
    }

    private func reportSyntaxCancellation(_ samples: [Double]) {
        reportJSON([
            "scenario": "syntax-cancellation-10mb",
            "completionSamplesMs": samples,
            "completionMedianMs": median(samples)
        ], scenario: "syntax-cancellation-10mb")
    }

    private func reportJSON(_ result: [String: Any], scenario: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            XCTFail("Unable to serialize Mac performance result for \(scenario)")
            return
        }
        print("RUNESTONE_MAC_PERFORMANCE_RESULT \(json)")
    }

    private func median<T: Comparable>(_ values: [T]) -> T {
        values.sorted()[values.count / 2]
    }

    private func elapsedMilliseconds(since start: TimeInterval) -> Double {
        (ProcessInfo.processInfo.systemUptime - start) * 1_000
    }

    private func residentBytes() -> UInt64 {
        var information = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.stride
        let count = withUnsafeMutablePointer(to: &information) { pointer in
            proc_pidinfo(getpid(), PROC_PIDTASKINFO, 0, pointer, Int32(size))
        }
        return count == size ? information.pti_resident_size : 0
    }
}

private struct Scenario {
    let name: String
    let isFolded: Bool
    let makeContent: () -> NSAttributedString
    let configure: (ReadOnlyDocumentView) -> Void

    init(name: String, isFolded: Bool = false, makeContent: @escaping () -> NSAttributedString,
         configure: @escaping (ReadOnlyDocumentView) -> Void = { _ in }) {
        self.name = name
        self.isFolded = isFolded
        self.makeContent = makeContent
        self.configure = configure
    }
}

private struct Trial {
    let loadMilliseconds: Double
    let traversalMilliseconds: Double
    let residentDeltaBytes: UInt64
    let residentObservationBytes: UInt64
    let utf8Bytes: Int
    let utf16Length: Int
    let logicalLines: Int
    let documentHeight: CGFloat
    let visibleUTF16Length: Int
}

private struct SyntaxScenario {
    let name: String
    let text: String
    var queryFolds = false
    var measuresIncrementalEdit = false
    var expectsVisibleCaptures = true
}

private struct SyntaxTrial {
    let parseMilliseconds: Double
    let captureMilliseconds: Double
    let foldMilliseconds: Double
    let incrementalMilliseconds: Double?
    let residentDeltaBytes: UInt64
    let residentObservationBytes: UInt64
    let utf8Bytes: Int
    let utf16Length: Int
    let captureCount: Int
    let foldCount: Int
}

private final class LockedResultBox<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: Result<Value, RunestoneSyntaxError>?

    var value: Result<Value, RunestoneSyntaxError>? { lock.withLock { storage } }

    func set(_ result: Result<Value, RunestoneSyntaxError>) {
        lock.withLock { storage = result }
    }
}
#endif
