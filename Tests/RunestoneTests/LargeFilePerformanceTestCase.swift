@testable import Runestone
import TestTreeSitterLanguages
import UIKit
import XCTest

/// Shared scrolling/editing timeline for JSON-shaped and plain ASCII documents.
@MainActor
class LargeFilePerformanceTestCase: XCTestCase {
    // swiftlint:disable:next function_body_length test_case_accessibility
    func run(longLines: Bool, highlighted: Bool, wrapping: Bool, unbroken: Bool = false, purePlainText: Bool = false) throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUNESTONE_PERFORMANCE"] == "1",
                          "Set RUNESTONE_PERFORMANCE=1 in the test runner to run the 25 MiB benchmark.")
        let fixture = makeFixture(lineLength: longLines ? 60_000 : 128, unbroken: unbroken, purePlainText: purePlainText)
        let lineKind = unbroken ? "long-unbroken" : (longLines ? "long" : "short")
        let prefix = purePlainText ? "pure-ascii-" : ""
        let scenario = "\(prefix)\(lineKind)-\(highlighted ? "json" : "plain")-\(wrapping ? "wrapped" : "unwrapped")"
        let view = TextView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        view.contentInsetAdjustmentBehavior = .never
        view.isLineWrappingEnabled = wrapping
        view.isAutomaticScrollEnabled = false
        view.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        view.autocorrectionType = .no
        view.spellCheckingType = .no
        let controller = UIViewController()
        controller.view = view
        let window = UIWindow(frame: view.frame)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            // Release document/controllers and cancel pending highlighting before
            // the next scenario. Do not retain the matrix through autorelease.
            view.text = ""
            window.isHidden = true
            window.rootViewController = nil
        }
        let input = try XCTUnwrap(view.subviews.compactMap { $0 as? TextInputView }.first)
        let loadStart = CACurrentMediaTime()
        if highlighted {
            let language = TreeSitterLanguage(tree_sitter_json(), highlightsQuery: .init(string: "(string) @string"))
            view.setState(TextViewState(text: fixture, language: language))
        } else {
            view.setState(TextViewState(text: fixture))
        }
        settle(view, input: input)
        let loadMilliseconds = milliseconds(since: loadStart)
        report(scenario: scenario, phase: "load", samples: [loadMilliseconds],
               extra: ["utf8Bytes": fixture.utf8.count, "logicalLines": input.lineManager.lineCount,
                       "maximumLineUTF8Bytes": maximumLineUTF8Bytes(in: fixture)])
        XCTAssertGreaterThanOrEqual(fixture.utf8.count, 25 * 1_024 * 1_024)
        XCTAssertEqual(input.string.length, fixture.utf16.count)

        // A display link leaves the main run loop free between callbacks, so
        // asynchronous highlighting, drawing and ordinary UIKit work can execute.
        let scrollFinished = expectation(description: "Scroll matrix \(scenario)")
        let driver = LargeFileScrollDriver(view: view, input: input) { scrollFinished.fulfill() }
        driver.start()
        wait(for: [scrollFinished], timeout: 150)
        driver.stop()
        for phase in driver.phases {
            report(scenario: scenario, phase: "scroll-\(phase)-work", samples: driver.work[phase] ?? [],
                   extra: ["endpoint": driver.endpoints[phase] ?? [:]])
            let intervals = driver.intervals[phase] ?? []
            report(scenario: scenario, phase: "scroll-\(phase)-interval", samples: intervals,
                   extra: ["over25ms": intervals.filter { $0 > 25 }.count,
                           "over50ms": intervals.filter { $0 > 50 }.count])
        }
        XCTAssertEqual(driver.completedFrames, driver.phases.count * driver.framesPerPhase)

        for position in ["start", "middle", "end"] {
            try measureEdits(view, input: input, scenario: scenario, position: position)
        }
        if longLines {
            try measureEdits(view, input: input, scenario: scenario, position: "middle", nearLineEnd: true)
        }
        // Full-document equality is deliberately outside every measured interval.
        XCTAssertEqual(input.string as String, fixture)
    }

    // swiftlint:disable:next function_body_length
    private func measureEdits(_ view: TextView, input: TextInputView, scenario: String, position: String,
                              nearLineEnd: Bool = false) throws {
        let row: Int
        switch position {
        case "start":
            row = 1
        case "middle":
            row = input.lineManager.lineCount / 2
        default:
            row = input.lineManager.lineCount - 3
        }
        let targetLine = input.lineManager.line(atRow: row)
        let location = targetLine.location + (nearLineEnd ? max(0, targetLine.data.length - 8) : 8)
        let positionLabel = nearLineEnd ? "\(position)-line-end" : position
        view.scrollRangeToVisible(NSRange(location: location, length: 0))
        settle(view, input: input)
        drainMainQueue()
        let initialLength = input.string.length
        let initialLineCount = input.lineManager.lineCount
        var timings: [String: [Double]] = [:]
        for _ in 0..<5 {
            // Restoring a deleted line invalidates its measured wrapped height.
            // Prepare the destination again so every edit starts at a visible caret.
            view.scrollRangeToVisible(NSRange(location: location, length: 0))
            settle(view, input: input)
            drainMainQueue()
            // Selection preparation is outside the sample, just as UIKit selects
            // the previous character before forwarding deleteBackward().
            view.selectedRange = NSRange(location: location, length: 0)
            sample("insert-character", into: &timings) {
                view.insertText("x")
                settle(view, input: input)
            }
            XCTAssertEqual(input.string.character(at: location), 120)
            XCTAssertEqual(view.selectedRange, NSRange(location: location + 1, length: 0))
            XCTAssertEqual(input.string.length, initialLength + 1)
            view.selectedRange = NSRange(location: location, length: 1)
            view.deleteBackward()
            settle(view, input: input)
            drainMainQueue()

            view.selectedRange = NSRange(location: location, length: 0)
            sample("insert-line-break", into: &timings) {
                view.insertText("\n")
                settle(view, input: input)
            }
            XCTAssertEqual(input.lineManager.lineCount, initialLineCount + 1)
            // The indentation controller may insert whitespace after the break.
            let insertedLength = input.string.length - initialLength
            XCTAssertGreaterThanOrEqual(insertedLength, 1)
            XCTAssertEqual(input.string.character(at: location), 10)
            view.selectedRange = NSRange(location: location, length: insertedLength)
            sample("join-line", into: &timings) {
                view.deleteBackward()
                settle(view, input: input)
            }
            XCTAssertEqual(input.lineManager.lineCount, initialLineCount)
            XCTAssertEqual(input.string.length, initialLength)
            drainMainQueue()

            let line = input.lineManager.line(atRow: row)
            let range = NSRange(location: line.location, length: line.data.totalLength)
            let removed = input.string.substring(with: range)
            view.selectedRange = range
            sample("delete-line", into: &timings) {
                view.deleteBackward()
                settle(view, input: input)
            }
            XCTAssertEqual(input.lineManager.lineCount, initialLineCount - 1)
            XCTAssertEqual(input.string.length, initialLength - range.length)
            XCTAssertEqual(view.selectedRange, NSRange(location: range.location, length: 0))
            view.replace(NSRange(location: range.location, length: 0), withText: removed)
            settle(view, input: input)
            XCTAssertEqual(input.lineManager.lineCount, initialLineCount)
            XCTAssertEqual(input.string.length, initialLength)
            // Undo history is not the workload and should not grow across trials.
            view.undoManager?.removeAllActions()
            drainMainQueue()
        }
        for operation in timings.keys.sorted() {
            report(scenario: scenario, phase: "edit-\(positionLabel)-\(operation)", samples: timings[operation]!)
        }
    }

    private func maximumLineUTF8Bytes(in text: String) -> Int {
        var current = 0
        var maximum = 0
        for byte in text.utf8 {
            if byte == 10 {
                maximum = max(maximum, current)
                current = 0
            } else {
                current += 1
            }
        }
        return max(maximum, current)
    }

    private func makeFixture(lineLength: Int, unbroken: Bool = false, purePlainText: Bool = false) -> String {
        if purePlainText {
            let phrase = unbroken ? "a" : "alpha beta gamma delta "
            let payload = String(String(repeating: phrase, count: lineLength / phrase.count + 1).prefix(lineLength))
            let line = payload + "\n"
            let count = (25 * 1_024 * 1_024 + line.utf8.count - 1) / line.utf8.count
            return String(repeating: line, count: count)
        }
        let phrase = unbroken ? "a" : "alpha beta gamma delta "
        let payloadLength = lineLength - 6
        let payload = String(String(repeating: phrase, count: payloadLength / phrase.count + 1).prefix(payloadLength))
        let line = "  \"\(payload)\",\n"
        let count = (25 * 1_024 * 1_024 + line.utf8.count - 1) / line.utf8.count
        return "[\n" + String(repeating: line, count: count - 1) + "  \"\(payload)\"\n]\n"
    }

    private func settle(_ view: TextView, input: TextInputView) {
        view.setNeedsLayout()
        view.layoutIfNeeded()
        input.setNeedsLayout()
        input.layoutIfNeeded()
        view.layoutIfNeeded()
    }

    private func drainMainQueue() {
        // This allows queued work to progress; it is not a claim that all
        // background highlighting has finished. There is no timed sleep in samples.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02))
    }

    private func sample(_ phase: String, into samples: inout [String: [Double]], action: () -> Void) {
        let start = CACurrentMediaTime()
        action()
        samples[phase, default: []].append(milliseconds(since: start))
    }

    private func milliseconds(since start: CFTimeInterval) -> Double {
        (CACurrentMediaTime() - start) * 1_000
    }

    private func report(scenario: String, phase: String, samples: [Double], extra: [String: Any] = [:]) {
        let sorted = samples.sorted()
        guard !sorted.isEmpty else {
            XCTFail("No samples for \(scenario)/\(phase)")
            return
        }
        var result = extra
        result["scenario"] = scenario
        result["phase"] = phase
        result["count"] = sorted.count
        result["medianMs"] = sorted[sorted.count / 2]
        result["p95Ms"] = sorted[min(sorted.count - 1, Int(ceil(Double(sorted.count) * 0.95)) - 1)]
        result["maxMs"] = sorted.last!
        result["samplesMs"] = samples
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            print("RUNESTONE_PERFORMANCE_RESULT \(json)")
        }
    }
}

@MainActor
private final class LargeFileScrollDriver: NSObject {
    let phases: [String]
    let framesPerPhase = 90
    private(set) var completedFrames = 0
    private(set) var work: [String: [Double]] = [:]
    private(set) var intervals: [String: [Double]] = [:]
    private(set) var endpoints: [String: [String: Double]] = [:]
    private let view: TextView
    private let input: TextInputView
    private let completion: () -> Void
    private var displayLink: CADisplayLink?
    private var previousTimestamp: CFTimeInterval?

    init(view: TextView, input: TextInputView, completion: @escaping () -> Void) {
        self.view = view
        self.input = input
        self.completion = completion
        phases = ["cold-slow", "cold-fast", "reverse", "revisit"]
            + (view.isLineWrappingEnabled ? [] : ["horizontal-out", "horizontal-back"])
    }

    func start() {
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFramesPerSecond = 60
        displayLink = link
        link.add(to: .main, forMode: .common)
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        let phaseIndex = completedFrames / framesPerPhase
        let phase = phases[phaseIndex]
        let now = CACurrentMediaTime()
        if completedFrames % framesPerPhase != 0, let previousTimestamp {
            intervals[phase, default: []].append((now - previousTimestamp) * 1_000)
        }
        previousTimestamp = now
        if phaseIndex < 4 {
            let distance: CGFloat = phaseIndex == 0 ? 40 : (phaseIndex == 2 ? -300 : 300)
            let maximumOffset = max(0, view.contentSize.height - view.bounds.height)
            view.contentOffset.y = min(maximumOffset, max(0, view.contentOffset.y + distance))
        } else {
            let distance: CGFloat = phaseIndex == 4 ? 100 : -100
            let maximumOffset = max(0, view.contentSize.width - view.bounds.width)
            view.contentOffset.x = min(maximumOffset, max(0, view.contentOffset.x + distance))
        }
        view.setNeedsLayout()
        view.layoutIfNeeded()
        input.setNeedsLayout()
        input.layoutIfNeeded()
        view.layoutIfNeeded()
        work[phase, default: []].append((CACurrentMediaTime() - now) * 1_000)
        completedFrames += 1
        if completedFrames % framesPerPhase == 0 {
            endpoints[phase] = [
                "offsetX": Double(view.contentOffset.x), "offsetY": Double(view.contentOffset.y),
                "contentWidth": Double(view.contentSize.width), "contentHeight": Double(view.contentSize.height),
                "viewportWidth": Double(view.bounds.width), "viewportHeight": Double(view.bounds.height)
            ]
        }
        if completedFrames == phases.count * framesPerPhase {
            stop()
            completion()
        }
    }
}
