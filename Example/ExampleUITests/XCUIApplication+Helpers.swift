import XCTest

private enum EnvironmentKey {
    static let disableTextPersistance = "disableTextPersistance"
}

extension XCUIApplication {
    func disablingTextPersistance() -> Self {
        var newLaunchEnvironment = launchEnvironment
        newLaunchEnvironment[EnvironmentKey.disableTextPersistance] = "1"
        launchEnvironment = newLaunchEnvironment
        return self
    }
}
