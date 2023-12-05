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

                private let _observableRegistry = _RunestoneObservation.ObservableRegistry<ViewModel>()

                func registerObserver<T>(
                    _ observer: some _RunestoneObservation.Observer,
                    observing keyPath: KeyPath<ViewModel, T>,
                    receiving changeType: _RunestoneObservation.PropertyChangeType,
                    options: _RunestoneObservation.ObservationOptions = [],
                    handler: @escaping _RunestoneObservation.ObservationChangeHandler<T>
                ) -> _RunestoneObservation.ObservationId {
                    return _observableRegistry.registerObserver(
                        observer,
                        observing: keyPath,
                        on: self,
                        receiving: changeType,
                        options: options,
                        handler: handler
                    )
                }

                func cancelObservation(withId observationId: _RunestoneObservation.ObservationId) {
                    _observableRegistry.cancelObservation(withId: observationId)
                }
            }

            extension ViewModel: _RunestoneObservation.Observable {
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func test_it_skips_tracking_properties_with_runestoneobservationignored_annotation() throws {
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

                private let _observableRegistry = _RunestoneObservation.ObservableRegistry<ViewModel>()

                func registerObserver<T>(
                    _ observer: some _RunestoneObservation.Observer,
                    observing keyPath: KeyPath<ViewModel, T>,
                    receiving changeType: _RunestoneObservation.PropertyChangeType,
                    options: _RunestoneObservation.ObservationOptions = [],
                    handler: @escaping _RunestoneObservation.ObservationChangeHandler<T>
                ) -> _RunestoneObservation.ObservationId {
                    return _observableRegistry.registerObserver(
                        observer,
                        observing: keyPath,
                        on: self,
                        receiving: changeType,
                        options: options,
                        handler: handler
                    )
                }

                func cancelObservation(withId observationId: _RunestoneObservation.ObservationId) {
                    _observableRegistry.cancelObservation(withId: observationId)
                }
            }

            extension ViewModel: _RunestoneObservation.Observable {
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

    func test_it_skips_adding_runestoneobservationtracked_annotation_when_already_added() throws {
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

                private let _observableRegistry = _RunestoneObservation.ObservableRegistry<ViewModel>()

                func registerObserver<T>(
                    _ observer: some _RunestoneObservation.Observer,
                    observing keyPath: KeyPath<ViewModel, T>,
                    receiving changeType: _RunestoneObservation.PropertyChangeType,
                    options: _RunestoneObservation.ObservationOptions = [],
                    handler: @escaping _RunestoneObservation.ObservationChangeHandler<T>
                ) -> _RunestoneObservation.ObservationId {
                    return _observableRegistry.registerObserver(
                        observer,
                        observing: keyPath,
                        on: self,
                        receiving: changeType,
                        options: options,
                        handler: handler
                    )
                }

                func cancelObservation(withId observationId: _RunestoneObservation.ObservationId) {
                    _observableRegistry.cancelObservation(withId: observationId)
                }
            }

            extension ViewModel: _RunestoneObservation.Observable {
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
