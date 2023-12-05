import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
#if canImport(_RunestoneMacros)
import _RunestoneMacros
#endif

final class RunestoneProxyMacroTests: XCTestCase {
    func test_it_generates_getter_and_setter() throws {
        #if canImport(_RunestoneMacros)
        assertMacroExpansion(
            """
            final class Parent {
                @RunestoneProxy(\\Parent.state.foo)
                var foo: String

                private final class State {
                    var foo = "foo"
                }

                private let state = State()
            }
            """,
            expandedSource: """
            final class Parent {
                var foo: String {
                    get {
                        return self [keyPath: \\Parent.state.foo]
                    }
                    set {
                        self [keyPath: \\Parent.state.foo] = newValue
                    }
                }

                private final class State {
                    var foo = "foo"
                }

                private let state = State()
            }
            """,
            macros: [
                "RunestoneProxy": RunestoneProxyMacro.self
            ]
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
