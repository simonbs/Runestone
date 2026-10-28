import Darwin
import QuartzCore
@testable import Runestone
import UIKit
import XCTest

/// Eligibility work runs before the first viewport. Measure late rejection and
/// unsupported fonts as well as successful long-line admission, without claiming
/// that a full-paragraph speedup establishes first-viewport performance.
@MainActor
final class LongLinePreparationPerformanceTests: XCTestCase {
    // swiftlint:disable:next function_body_length
    func testPreparationAndFirstViewport() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUNESTONE_PERFORMANCE"] == "1")
        for length in [60_000, 1_048_576] {
            for fixture in ["alphanumeric", "quoted-payload", "opening-payload", "closing-payload",
                            "unsupported-font", "late-unicode", "words", "json-wrapper"] {
                let body = String(repeating: "a", count: length)
                let contents = fixtureContents(fixture, body: body, length: length)
                let theme = DefaultTheme.shared
                let font = fixture == "unsupported-font" ? UIFont.systemFont(ofSize: 14) : theme.font
                let text = NSMutableAttributedString(string: contents)
                DefaultStringAttributes(textColor: theme.textColor, font: font, kern: 0,
                                        tabWidth: TabWidthMeasurer.tabWidth(tabLength: 4, font: font)).apply(to: text)
                for width in [CGFloat(320), 10_000] {
                    var preparation: [Double] = []
                    var total: [Double] = []
                    var preparationCPU: [Double] = []
                    var totalCPU: [Double] = []
                    for trial in 0..<4 {
                        autoreleasepool {
                            let typesetter = LineTypesetter(lineID: "first-viewport")
                            typesetter.constrainingWidth = width
                            let cpuStart = threadCPUTime()
                            let start = CACurrentMediaTime()
                            typesetter.prepareToTypeset(text)
                            let prepared = CACurrentMediaTime()
                            let cpuPrepared = threadCPUTime()
                            typesetter.typesetLineFragments(in: CGRect(x: 0, y: 0, width: width, height: 700))
                            let finished = CACurrentMediaTime()
                            let cpuFinished = threadCPUTime()
                            XCTAssertGreaterThan(typesetter.typesetLength, 0)
                            XCTAssertLessThanOrEqual(typesetter.typesetLength, text.length)
                            XCTAssertEqual(typesetter.lineFragments.first?.range.location, 0)
                            if trial > 0 {
                                preparation.append((prepared - start) * 1_000)
                                total.append((finished - start) * 1_000)
                                preparationCPU.append((cpuPrepared - cpuStart) * 1_000)
                                totalCPU.append((cpuFinished - cpuStart) * 1_000)
                            }
                        }
                    }
                    let result: [String: Any] = [
                        "fixture": fixture, "utf16": text.length, "width": Double(width),
                        "prepareSamplesMs": preparation, "firstViewportSamplesMs": total,
                        "prepareThreadCPUSamplesMs": preparationCPU, "firstViewportThreadCPUSamplesMs": totalCPU,
                        "prepareMedianMs": preparation.sorted()[1], "firstViewportMedianMs": total.sorted()[1]
                    ]
                    let data = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
                    let json = try XCTUnwrap(String(data: data, encoding: .utf8))
                    print("LONG_LINE_PREPARATION \(json)")
                }
            }
        }
    }

    private func fixtureContents(_ fixture: String, body: String, length: Int) -> String {
        switch fixture {
        case "quoted-payload":
            return "  \"" + body + "\",\n"
        case "opening-payload":
            return "  \"" + body + "\n"
        case "closing-payload":
            return body + "\",\n"
        case "late-unicode":
            return body + "é"
        case "words":
            return String(String(repeating: "alpha beta ", count: length / 11 + 1).prefix(length))
        case "json-wrapper":
            return "{\"value\":\"" + body + "\"}"
        default:
            return body
        }
    }

    private func threadCPUTime() -> Double {
        var time = timespec()
        let status = clock_gettime(CLOCK_THREAD_CPUTIME_ID, &time)
        precondition(status == 0, "Thread CPU clock is unavailable")
        return Double(time.tv_sec) + Double(time.tv_nsec) / 1_000_000_000
    }
}
