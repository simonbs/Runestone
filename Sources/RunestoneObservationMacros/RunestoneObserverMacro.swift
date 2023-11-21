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
            try makeObserverRegistryVariable(),
            try makeObserveFunction()
        ]
    }
}

private extension RunestoneObserverMacro {
    private static func makeObserverRegistryVariable() throws -> DeclSyntax {
        let syntax = try VariableDeclSyntax(
           """
           private let _observerRegistry = RunestoneObservation.ObserverRegistry()
           """
        )
        return DeclSyntax(syntax)
    }

    private static func makeObserveFunction() throws -> DeclSyntax {
        let syntax = try FunctionDeclSyntax(
           """
           func observe<T: RunestoneObservation.Observable, U>(
               _ keyPath: KeyPath<T, U>,
               of observable: T,
               receiving changeType: RunestoneObservation.PropertyChangeType = .didSet,
               options: RunestoneObservation.ObservationOptions = [],
               handler: @escaping RunestoneObservation.ObservationChangeHandler<U>
           ) {
               _observerRegistry.registerObserver(
                   observing: keyPath,
                   of: observable,
                   receiving: changeType,
                   options: options,
                   handler: handler
               )
           }
           """
        )
        return DeclSyntax(syntax)
    }
}
