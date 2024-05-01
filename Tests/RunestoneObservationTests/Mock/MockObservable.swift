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
    var equatableObj = MyEquatableType("foo")
    var nonEquatableObj = MyNonEquatableType("foo")
    let constantProp = MyEquatableType("foo")
}
