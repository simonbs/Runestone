@testable import _RunestoneObservation

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

@RunestoneObservable
final class MockObservable {
    var str = "foo"
    let equatableObj = MyEquatableType("foo")
    let nonEquatableObj = MyNonEquatableType("foo")
}
