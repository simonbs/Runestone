import SwiftSyntax
import SwiftCompilerPluginMessageHandling
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct RunestoneObserverMacro {}

extension RunestoneObserverMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(ClassDeclSyntax.self) else {
            let diagnostic = Diagnostic(
                node: declaration,
                message: RunestoneMacroDiagnostic.onlyApplicableToClass
            )
            context.diagnose(diagnostic)
            return []
        }
        return [
            try makeObserverRegistrarVariable(),
            try makeObserveFunction()
        ]
    }
}

private extension RunestoneObserverMacro {
    private static func makeObserverRegistrarVariable() throws -> DeclSyntax {
        let syntax = try VariableDeclSyntax(
           """
           private let _observerRegistrar = _RunestoneObservation.ObserverRegistrar()
           """
        )
        return DeclSyntax(syntax)
    }

    private static func makeObserveFunction() throws -> DeclSyntax {
        let syntax = try FunctionDeclSyntax(
           """
           @discardableResult
           private func observe<T>(
               _ tracker: @escaping () -> T,
               options: _RunestoneObservation.ObservationOptions = [],
               handler: @escaping _RunestoneObservation.ObservationChangeHandler<T>
           ) -> _RunestoneObservation.Observation {
               _observerRegistrar.registerObserver(
                   tracking: tracker,
                   options: options,
                   handler: handler
               )
           }

           @discardableResult
           private func observe<T>(
               _ tracker: @escaping @autoclosure () -> T,
               options: _RunestoneObservation.ObservationOptions = [],
               handler: @escaping _RunestoneObservation.ObservationChangeHandler<T>
           ) -> _RunestoneObservation.Observation {
               _observerRegistrar.registerObserver(
                   tracking: tracker,
                   options: options,
                   handler: handler
               )
           }

           @discardableResult
           private func observe<T: Equatable>(
               _ tracker: @escaping () -> T,
               options: _RunestoneObservation.ObservationOptions = [],
               handler: @escaping _RunestoneObservation.ObservationChangeHandler<T>
           ) -> _RunestoneObservation.Observation {
               _observerRegistrar.registerObserver(
                   tracking: tracker,
                   options: options,
                   handler: handler
               )
           }

           @discardableResult
           private func observe<T: Equatable>(
               _ tracker: @escaping @autoclosure () -> T,
               options: _RunestoneObservation.ObservationOptions = [],
               handler: @escaping _RunestoneObservation.ObservationChangeHandler<T>
           ) -> _RunestoneObservation.Observation {
               _observerRegistrar.registerObserver(
                   tracking: tracker,
                   options: options,
                   handler: handler
               )
           }
           """
        )
        return DeclSyntax(syntax)
    }
}
