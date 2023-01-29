import XCTest

private enum EnvironmentKey {
    static let crlfLineEndings = "crlfLineEndings"
}

extension XCUIApplication {
    var textView: XCUIElement? {
        textViews["RunestoneTextView"]
    }

    func tap(at point: CGPoint) {
        let normalized = coordinate(withNormalizedOffset: .zero)
        let offset = CGVector(dx: point.x, dy: point.y)
        let coordinate = normalized.withOffset(offset)
        coordinate.tap()
    }

    func usingCRLFLineEndings() -> Self {
        var newLaunchEnvironment = launchEnvironment
        newLaunchEnvironment[EnvironmentKey.crlfLineEndings] = "1"
        launchEnvironment = newLaunchEnvironment
        return self
    }
}
