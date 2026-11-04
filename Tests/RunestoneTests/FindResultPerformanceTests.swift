@testable import Runestone
import UIKit
import XCTest

@MainActor
final class FindResultPerformanceTests: XCTestCase {
    func testThousandMatchesRemainResponsive() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUNESTONE_PERFORMANCE"] == "1")
        let view = TextView(frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        view.contentInsetAdjustmentBehavior = .never
        view.text = (0 ..< 1_000).map { "postId: \($0)" }.joined(separator: "\n")
        let controller = UIViewController()
        controller.view = view
        let window = UIWindow(frame: view.frame)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        view.layoutIfNeeded()

        let searchStart = CACurrentMediaTime()
        let ranges = matches(of: "post", in: view.text)
        report(phase: "search-1000-matches", milliseconds: (CACurrentMediaTime() - searchStart) * 1_000)
        let applyStart = CACurrentMediaTime()
        var highlights = ranges.enumerated().map { index, range in
            highlight(range, selected: index == 0)
        }
        view.isFindResultPresentationActive = true
        view.highlightedRanges = highlights
        view.layoutIfNeeded()
        report(phase: "apply-1000-matches", milliseconds: (CACurrentMediaTime() - applyStart) * 1_000)

        let cycleStart = CACurrentMediaTime()
        for selectedIndex in 1 ... 100 {
            highlights[selectedIndex - 1] = highlight(ranges[selectedIndex - 1], selected: false)
            highlights[selectedIndex] = highlight(ranges[selectedIndex], selected: true)
            view.highlightedRanges = highlights
            view.scrollRangeToVisible(ranges[selectedIndex])
        }
        report(phase: "cycle-100-matches", milliseconds: (CACurrentMediaTime() - cycleStart) * 1_000)

        let finished = expectation(description: "Scroll with 1,000 matches")
        let driver = FindResultScrollDriver(view: view) { finished.fulfill() }
        driver.start()
        wait(for: [finished], timeout: 15)
        driver.stop()
        report(phase: "scroll-frame-work", samples: driver.work)
        report(phase: "scroll-frame-interval", samples: driver.intervals,
               extra: ["over25ms": driver.intervals.filter { $0 > 25 }.count,
                       "over50ms": driver.intervals.filter { $0 > 50 }.count])
        XCTAssertEqual(driver.completedFrames, driver.frameCount)
    }

    private func matches(of query: String, in text: String) -> [NSRange] {
        guard let expression = try? NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: query)) else {
            XCTFail("Unable to create search expression")
            return []
        }
        return expression.matches(in: text, range: NSRange(location: 0, length: text.utf16.count)).map(\.range)
    }

    private func highlight(_ range: NSRange, selected: Bool) -> HighlightedRange {
        HighlightedRange(range: range, color: selected ? .systemYellow : .systemYellow.withAlphaComponent(0.2),
                         cornerRadius: selected ? 5 : 3,
                         presentationRole: selected ? .selectedSearchResult : .foundSearchResult)
    }

    private func report(phase: String, milliseconds: Double) {
        report(phase: phase, samples: [milliseconds])
    }

    private func report(phase: String, samples: [Double], extra: [String: Any] = [:]) {
        let sorted = samples.sorted()
        var result = extra
        result["phase"] = phase
        result["sampleCount"] = samples.count
        result["meanMs"] = samples.reduce(0, +) / Double(max(1, samples.count))
        result["maxMs"] = sorted.last ?? 0
        result["p95Ms"] = sorted.isEmpty ? 0 : sorted[min(sorted.count - 1, Int(ceil(Double(sorted.count) * 0.95)) - 1)]
        guard let data = try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]),
              let message = String(bytes: data, encoding: .utf8) else {
            XCTFail("Unable to encode performance result")
            return
        }
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = phase
        attachment.lifetime = .keepAlways
        add(attachment)
        print("RUNESTONE_FIND_PERFORMANCE \(message)")
    }
}

@MainActor
private final class FindResultScrollDriver: NSObject {
    let frameCount = 180
    private(set) var completedFrames = 0
    private(set) var work: [Double] = []
    private(set) var intervals: [Double] = []
    private let view: TextView
    private let completion: () -> Void
    private var displayLink: CADisplayLink?
    private var previousTimestamp: CFTimeInterval?

    init(view: TextView, completion: @escaping () -> Void) {
        self.view = view
        self.completion = completion
    }

    func start() {
        let displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink.preferredFramesPerSecond = 60
        self.displayLink = displayLink
        displayLink.add(to: .main, forMode: .common)
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick() {
        let start = CACurrentMediaTime()
        if let previousTimestamp {
            intervals.append((start - previousTimestamp) * 1_000)
        }
        previousTimestamp = start
        let direction: CGFloat = completedFrames < frameCount / 2 ? 90 : -90
        let maximumOffset = max(0, view.contentSize.height - view.bounds.height)
        view.contentOffset.y = min(maximumOffset, max(0, view.contentOffset.y + direction))
        view.layoutIfNeeded()
        work.append((CACurrentMediaTime() - start) * 1_000)
        completedFrames += 1
        if completedFrames == frameCount {
            stop()
            completion()
        }
    }
}
