import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
#if canImport(_RunestoneMacros)
import _RunestoneMacros

private let testMacros: [String: Macro.Type] = [
    "RunestoneObservable": RunestoneObservableMacro.self
]
#endif

final class RunestoneObservableMacroTests: XCTestCase {
    func test_it_generates_observable_conformance() throws {
        #if canImport(_RunestoneMacros)
        assertMacroExpansion(
            """
            @RunestoneObservable
            final class ViewModel {
                var foo: String = ""
            }
            """,
            expandedSource: """
            final class ViewModel {
                @RunestoneObservationTracked
                var foo: String = ""

                private let _observableRegistrar = _RunestoneObservation.ObservableRegistrar()
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func test_it_skips_tracking_properties_withRunestoneObservationignored_annotation() throws {
        #if canImport(_RunestoneMacros)
        assertMacroExpansion(
            """
            @RunestoneObservable
            final class ViewModel {
                var foo: String = ""
                @RunestoneObservationIgnored
                var bar: String = ""
            }
            """,
            expandedSource: """
            final class ViewModel {
                @RunestoneObservationTracked
                var foo: String = ""
                @RunestoneObservationIgnored
                var bar: String = ""

                private let _observableRegistrar = _RunestoneObservation.ObservableRegistrar()
            }
            """,
            macros: [
                "RunestoneObservable": RunestoneObservableMacro.self
            ]
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func test_it_skips_addingRunestoneObservationtracked_annotation_when_already_added() throws {
        #if canImport(_RunestoneMacros)
        assertMacroExpansion(
            """
            @RunestoneObservable
            final class ViewModel {
                @RunestoneObservationTracked
                var foo: String = ""
            }
            """,
            expandedSource: """
            final class ViewModel {
                @RunestoneObservationTracked
                var foo: String = ""

                private let _observableRegistrar = _RunestoneObservation.ObservableRegistrar()
            }
            """,
            macros: [
                "RunestoneObservable": RunestoneObservableMacro.self
            ]
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
