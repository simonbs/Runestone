@testable import RunestoneObservation

struct MyEquatableType: Equatable {
    let str: String

    init(_ str: String) {
        self.str = str
    }
}

struct MyNonEquatableType {
    let str: String

    init(_ str: String) {
        self.str = str
    }
}

final class MockObservable: Observable {
    var str = "foo"
    let equatableObj = MyEquatableType("foo")
    let nonEquatableObj = MyNonEquatableType("foo")

    private(set) var didCancel = false

    func registerObserver<T>(
        _ observer: some Observer,
        observing keyPath: KeyPath<MockObservable, T>,
        receiving changeType: PropertyChangeType,
        options: ObservationOptions,
        handler: @escaping ObservationChangeHandler<T>
    ) -> ObservationId {
         ObservationId()
    }
    
    func cancelObservation(withId observationId: ObservationId) {
        didCancel = true
    }
}
