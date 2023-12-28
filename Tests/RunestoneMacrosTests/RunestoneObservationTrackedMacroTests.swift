import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
#if canImport(_RunestoneMacros)
import _RunestoneMacros

private let testMacros: [String: Macro.Type] = [
    "RunestoneObservationTracked": RunestoneObservationTrackedMacro.self
]
#endif

final class RunestoneObservationTrackedMacroTests: XCTestCase {
    func test_it_generates_will_set_and_did_set() throws {
        #if canImport(_RunestoneMacros)
        assertMacroExpansion(
            """
            final class ViewModel {
                @RunestoneObservationTracked
                var foo: String = ""
            }
            """,
            expandedSource: """
            final class ViewModel {
                var foo: String = "" {
                    @storageRestrictions(initializes: _foo)
                    init(initialValue) {
                        _foo = initialValue
                    }
                    set {
                        _observableRegistry.mutating(
                            \\.foo,
                            on: self,
                            changingFrom: foo,
                            to: newValue
                        ) {
                            _foo = newValue
                        }
                    }
                    get {
                         _foo
                    }
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
