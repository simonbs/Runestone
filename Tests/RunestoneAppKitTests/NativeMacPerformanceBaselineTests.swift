#if canImport(AppKit)
import AppKit
import Darwin
@testable import RunestoneAppKit
import RunestoneEngine
import XCTest

/// Opt-in Release measurements for the AppKit/Core Text document surface.
///
/// These results are machine-specific baselines, not pass/fail budgets. Fixture
/// construction and syntax parsing are outside the samples; load includes the
/// view's attributed-snapshot copy, line indexing and first viewport layout.
@MainActor
final class NativeMacPerformanceBaselineTests: XCTestCase {
    private let viewport = NSSize(width: 700, height: 480)
    private let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

    func testRepresentativeAppKitScenarios() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUNESTONE_MAC_PERFORMANCE"] == "1",
                          "Set RUNESTONE_MAC_PERFORMANCE=1 for opt-in Release measurements.")

        let requestedScenario = ProcessInfo.processInfo.environment["RUNESTONE_MAC_PERFORMANCE_SCENARIO"]
        let scenarios = makeScenarios().filter { requestedScenario == nil || $0.name == requestedScenario }
        XCTAssertFalse(scenarios.isEmpty, "Requested Mac performance scenario does not exist.")
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
#endif
