import XCTest

private enum EnvironmentKey {
    static let disableTextPersistance = "disableTextPersistance"
    static let crlfLineEndings = "crlfLineEndings"
}

extension XCUIApplication {
    var textView: XCUIElement? {
        scrollViews.children(matching: .textView).element
    }

    func disablingTextPersistance() -> Self {
        var newLaunchEnvironment = launchEnvironment
        newLaunchEnvironment[EnvironmentKey.disableTextPersistance] = "1"
        launchEnvironment = newLaunchEnvironment
        return self
    }

    func usingCRLFLineEndings() -> Self {
        var newLaunchEnvironment = launchEnvironment
        newLaunchEnvironment[EnvironmentKey.crlfLineEndings] = "1"
        launchEnvironment = newLaunchEnvironment
        return self
    }
}
