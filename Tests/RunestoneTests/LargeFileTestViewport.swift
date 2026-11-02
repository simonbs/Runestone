import UIKit

/// Keep the original benchmark geometry by default. Opt in separately to screen
/// dimensions when checking tablet-sized layout; those timings are a new series.
@MainActor
enum LargeFileTestViewport {
    static func frame(defaultSize: CGSize) -> CGRect {
        let useScreen = ProcessInfo.processInfo.environment["RUNESTONE_PERFORMANCE_SCREEN_VIEWPORT"] == "1"
        return CGRect(origin: .zero, size: useScreen ? UIScreen.main.bounds.size : defaultSize)
    }
}
