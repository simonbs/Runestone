import Darwin
@testable import Runestone
import TestTreeSitterLanguages
import UIKit
import XCTest

/// Opt-in distributed traversal of a 25 MiB highlighted document. This complements
/// LargeFilePerformanceTests' continuous initial traversal with middle/end regions.
/// Timing is synchronous navigation/layout, not compositor or touch-input latency.
/// Memory is whole-process residency/footprint, including allocator and test history;
/// it must not be interpreted as retained controller memory or a leak measurement.
@MainActor
final class LargeFileTraversalTests: XCTestCase {
    func testShortLinesWrapped() throws { try traverse(longLines: false, wrapping: true) }
    func testShortLinesUnwrapped() throws { try traverse(longLines: false, wrapping: false) }
    func testLongLinesWrapped() throws { try traverse(longLines: true, wrapping: true) }
    func testLongLinesUnwrapped() throws { try traverse(longLines: true, wrapping: false) }

    // swiftlint:disable:next function_body_length
    private func traverse(longLines: Bool, wrapping: Bool) throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUNESTONE_PERFORMANCE"] == "1",
                          "Set RUNESTONE_PERFORMANCE=1 in the test runner to run distributed traversal.")
        let fixture = makeFixture(lineLength: longLines ? 60_000 : 128)
        let scenario = "\(longLines ? "long" : "short")-json-\(wrapping ? "wrapped" : "unwrapped")"
        let view = TextView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        view.contentInsetAdjustmentBehavior = .never
        view.isLineWrappingEnabled = wrapping
        view.isAutomaticScrollEnabled = false
        view.autocorrectionType = .no
        view.spellCheckingType = .no
        view.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        let controller = UIViewController()
        controller.view = view
        let window = UIWindow(frame: view.frame)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            view.text = ""
            window.isHidden = true
            window.rootViewController = nil
        }
        let input = try XCTUnwrap(view.subviews.compactMap { $0 as? TextInputView }.first)
        report(scenario: scenario, stage: "before-load", view: view,
               extra: ["utf8Bytes": fixture.utf8.count])
        let language = TreeSitterLanguage(tree_sitter_json(), highlightsQuery: .init(string: "(string) @string"))
        let start = CACurrentMediaTime()
        view.setState(TextViewState(text: fixture, language: language))
        settle(view, input: input)
        let loadMilliseconds = (CACurrentMediaTime() - start) * 1_000
        view.selectedRange = NSRange(location: 0, length: 0)
        let selection = view.selectedRange
        drainMainQueue()
        report(scenario: scenario, stage: "after-load", view: view,
               extra: ["loadMs": loadMilliseconds, "logicalLines": input.lineManager.lineCount])
        XCTAssertGreaterThanOrEqual(fixture.utf8.count, 25 * 1_024 * 1_024)

        for destination in 0..<12 {
            // Keep destinations on actual payload lines, including the first and
            // final payload, rather than the array delimiters or trailing blank line.
            let row = 1 + (input.lineManager.lineCount - 4) * destination / 11
            let location = input.lineManager.line(atRow: row).location + 8
            let navigationMilliseconds = navigate(to: location, view: view, input: input)
            try validateViewport(view, input: input, selection: selection)
            var scrollMilliseconds: [Double] = []
            for step in 0..<12 {
                let delta = view.bounds.height / 3 * (step < 6 ? 1 : -1)
                let scrollStart = CACurrentMediaTime()
                view.contentOffset.y = min(max(0, view.contentSize.height - view.bounds.height),
                                           max(0, view.contentOffset.y + delta))
                settle(view, input: input)
                scrollMilliseconds.append((CACurrentMediaTime() - scrollStart) * 1_000)
                drainMainQueue()
                try validateViewport(view, input: input, selection: selection)
            }
            report(scenario: scenario, stage: "destination", view: view,
                   extra: ["destination": destination, "row": row, "location": location,
                           "navigationMs": navigationMilliseconds, "scrollLayoutMs": scrollMilliseconds,
                           "scrollLayoutMaxMs": scrollMilliseconds.max() ?? 0])
        }
        for (stage, location) in [("eof-revisit", input.string.length), ("top-revisit", 0)] {
            let duration = navigate(to: location, view: view, input: input)
            try validateViewport(view, input: input, selection: selection)
            report(scenario: scenario, stage: stage, view: view, extra: ["navigationMs": duration])
        }
        XCTAssertEqual(input.string as String, fixture)
        view.text = ""
        settle(view, input: input)
        drainMainQueue()
        report(scenario: scenario, stage: "after-document-release", view: view)
    }

    private func navigate(to location: Int, view: TextView, input: TextInputView) -> Double {
        let start = CACurrentMediaTime()
        view.scrollRangeToVisible(NSRange(location: location, length: 0))
        settle(view, input: input)
        let duration = (CACurrentMediaTime() - start) * 1_000
        drainMainQueue()
        return duration
    }

    private func validateViewport(_ view: TextView, input: TextInputView, selection: NSRange) throws {
        XCTAssertEqual(view.selectedRange, selection, "Scrolling must not change the editing selection.")
        XCTAssertTrue(view.contentSize.width.isFinite && view.contentSize.height.isFinite)
        XCTAssertTrue(view.contentOffset.x.isFinite && view.contentOffset.y.isFinite)
        XCTAssertGreaterThan(view.contentSize.height, 0)
        let fragments = visibleFragments(in: view)
        XCTAssertFalse(fragments.isEmpty, "A distant traversal must produce visible text fragments.")
        XCTAssertTrue(fragments.contains { fragment in
            guard let renderer = fragment.renderer else {
                return false
            }
            return CTLineGetGlyphCount(renderer.lineFragment.line) > 0
        }, "A viewport containing only empty fragments cannot establish visible text.")
        for fragment in fragments {
            _ = try XCTUnwrap(fragment.renderer)
            XCTAssertTrue(fragment.frame.minY.isFinite && fragment.frame.height.isFinite)
        }
        assertContinuousCoverage(fragments, in: view, input: input)
    }

    private func assertContinuousCoverage(_ fragments: [LineFragmentView], in view: TextView, input: TextInputView,
                                          file: StaticString = #filePath, line: UInt = #line) {
        let frames = fragments.map { $0.convert($0.bounds, to: view) }.sorted { $0.minY < $1.minY }
        guard let first = frames.first, let last = frames.last else {
            return // validateViewport already reports an empty viewport.
        }
        let finalLine = input.lineManager.lastLine
        // The empty logical line after the final newline has caret height but no
        // renderer. Exclude only that known EOF row, plus document container insets.
        // Interior empty lines contain a newline and must still have contiguous views.
        let finalRenderedHeight = finalLine.data.totalLength == 0 ? 0 : finalLine.data.lineHeight
        let documentTop = input.convert(CGPoint(x: 0, y: view.textContainerInset.top), to: view).y
        let documentBottom = input.convert(CGPoint(x: 0, y: view.textContainerInset.top
                                                       + finalLine.yPosition + finalRenderedHeight), to: view).y
        let expectedTop = max(view.bounds.minY, documentTop)
        let expectedBottom = min(view.bounds.maxY, documentBottom)
        XCTAssertLessThanOrEqual(first.minY, expectedTop + 0.5,
                                 "Text must cover the viewport below its top container inset.", file: file, line: line)
        XCTAssertGreaterThanOrEqual(last.maxY, expectedBottom - 0.5,
                                    "Text must cover the viewport through its final rendered EOF row.", file: file, line: line)
        for (previous, next) in zip(frames, frames.dropFirst()) {
            XCTAssertEqual(previous.maxY, next.minY, accuracy: 0.5,
                           "Visible fragments must meet without gaps or overlaps.", file: file, line: line)
        }
    }

    private func visibleFragments(in view: TextView) -> [LineFragmentView] {
        func descendants(of parent: UIView) -> [LineFragmentView] {
            parent.subviews.flatMap { child in
                if let fragment = child as? LineFragmentView {
                    return [fragment]
                }
                return descendants(of: child)
            }
        }
        return descendants(of: view).filter { fragment in
            !fragment.isHidden && fragment.renderer != nil && fragment.convert(fragment.bounds, to: view).intersects(view.bounds)
        }
    }

    private func makeFixture(lineLength: Int) -> String {
        let phrase = "alpha beta gamma delta "
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
        // Permit asynchronous styling/drawing between samples; this does not
        // assert completion of all queued highlighting or measure frame delivery.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02))
    }

    private func memorySample() -> [String: Double] {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rawInfo in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rawInfo, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return [:]
        }
        let mebibyte = 1_024.0 * 1_024.0
        return ["residentMiB": Double(info.resident_size) / mebibyte,
                "physicalFootprintMiB": Double(info.phys_footprint) / mebibyte]
    }

    private func report(scenario: String, stage: String, view: TextView, extra: [String: Any] = [:]) {
        var result = extra
        result["scenario"] = scenario
        result["stage"] = stage
        result["memory"] = memorySample()
        result["offsetX"] = Double(view.contentOffset.x)
        result["offsetY"] = Double(view.contentOffset.y)
        result["contentWidth"] = Double(view.contentSize.width)
        result["contentHeight"] = Double(view.contentSize.height)
        result["visibleFragmentCount"] = visibleFragments(in: view).count
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
           let json = String(data: data, encoding: .utf8) {
            print("RUNESTONE_TRAVERSAL_RESULT \(json)")
        }
    }
}
