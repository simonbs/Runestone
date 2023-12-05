import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
#if canImport(_RunestoneMacros)
import _RunestoneMacros

private let testMacros: [String: Macro.Type] = [
    "RunestoneObserver": RunestoneObserverMacro.self
]
#endif

final class RunestoneObserverMacroTests: XCTestCase {
    func test_it_generates_observer_conformance() throws {
        #if canImport(_RunestoneMacros)
        assertMacroExpansion(
            """
            @RunestoneObserver
            final class ViewModel {

            }
            """,
            expandedSource: """
            final class ViewModel {

                private let _observerRegistry = _RunestoneObservation.ObserverRegistry()

                func observe<T: _RunestoneObservation.Observable, U>(
                    _ keyPath: KeyPath<T, U>,
                    of observable: T,
                    receiving changeType: _RunestoneObservation.PropertyChangeType = .didSet,
                    options: _RunestoneObservation.ObservationOptions = [],
                    handler: @escaping _RunestoneObservation.ObservationChangeHandler<U>
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
