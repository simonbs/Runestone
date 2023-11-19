import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
#if canImport(RunestoneObservationMacros)
import RunestoneObservationMacros

private let testMacros: [String: Macro.Type] = [
    "RunestoneObserver": RunestoneObserverMacro.self
]
#endif

final class RunestoneObserverMacroTests: XCTestCase {
    func test_it_generates_observer_conformance() throws {
        #if canImport(RunestoneObservationMacros)
        assertMacroExpansion(
            """
            @RunestoneObserver
            final class ViewModel {

            }
            """,
            expandedSource: """
            final class ViewModel {

                private let _observerRegistry = RunestoneObservationMacro.ObserverRegistry()

                func observe<T: RunestoneObservationMacro.Observable, U>(
                    _ keyPath: KeyPath<T, U>,
                    of observable: T,
                    receiving changeType: RunestoneObservationMacro.PropertyChangeType = .didSet,
                    options: RunestoneObservationMacro.ObservationOptions = [],
                    handler: @escaping RunestoneObservationMacro.ObservationChangeHandler<U>
                ) {
                    _observerRegistry.registerObserver(
                        observing: keyPath,
                        of: observable,
                        receiving: changeType,
                        options: options,
                        handler: handler
                    )
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
