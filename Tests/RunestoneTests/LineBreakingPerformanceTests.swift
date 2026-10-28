import CoreText
import Foundation
@testable import Runestone
import UIKit
import XCTest

@MainActor
final class LineBreakingPerformanceTests: XCTestCase {
    /// Opt-in because these fully measure pathological paragraphs instead of the
    /// small visible prefix normally needed by the editor.
    func testLongLineTypesettingPerformance() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["RUNESTONE_PERFORMANCE"] == "1",
                          "Set RUNESTONE_PERFORMANCE=1 to run long-line performance measurements.")
        let mixedPattern = "identifier = \"café 👩‍💻 مرحبا אבג\";\tvalue /path_to.file, \u{200B}\u{00A0} "
        let fixtures = [
            ("ascii", String(repeating: "a", count: 60_000)),
            ("mixed", String(repeating: mixedPattern, count: 60_000 / mixedPattern.utf16.count))
        ]
        for (name, text) in fixtures {
            let string = NSMutableAttributedString(string: text)
            DefaultStringAttributes(textColor: .black, font: .monospacedSystemFont(ofSize: 17, weight: .regular),
                                    kern: 0, tabWidth: 40).apply(to: string)
            // Match LayoutManager's existing 10,000-point limit when wrapping is off.
            for width in [CGFloat(320), CGFloat(10_000)] {
                var samples: [Double] = []
                var fragmentCount = 0
                for trial in 0 ... 8 {
                    autoreleasepool {
                        let typesetter = LineTypesetter(lineID: "benchmark")
                        typesetter.constrainingWidth = width
                        let start = ProcessInfo.processInfo.systemUptime
                        typesetter.prepareToTypeset(string)
                        typesetter.typesetLineFragments(toLocation: string.length)
                        let milliseconds = (ProcessInfo.processInfo.systemUptime - start) * 1_000
                        if trial > 0 {
                            samples.append(milliseconds)
                        }
                        XCTAssertEqual(typesetter.typesetLength, string.length)
                        fragmentCount = typesetter.lineFragments.count
                    }
                }
                let sorted = samples.sorted()
                let median = (sorted[3] + sorted[4]) / 2
                let values = samples.map { String(format: "%.3f", $0) }.joined(separator: ",")
                print("LINE_BREAK_PERF fixture=\(name) utf16=\(string.length) width=\(Int(width)) "
                      + "fragments=\(fragmentCount) median_ms=\(String(format: "%.3f", median)) samples_ms=[\(values)]")
            }
        }
    }

}
