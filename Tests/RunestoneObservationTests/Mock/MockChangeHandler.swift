@testable import _RunestoneObservation

final class MockChangeHandler: ChangeHandler {
    private(set) var didCallInvoke = false

    func invoke() throws {
        didCallInvoke = true
    }
}
