import SwiftSyntax
import SwiftCompilerPluginMessageHandling
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct RunestoneObservableMacro {}

extension RunestoneObservableMacro: MemberAttributeMacro {
    private static let trackedMacroName = "RunestoneObservationTracked"
    private static let ignoredMacroName = "RunestoneObservationIgnored"

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingAttributesFor member: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AttributeSyntax] {
        guard let variableDecl = member.as(VariableDeclSyntax.self) else {
            return []
        }
        guard variableDecl.isValidForObservation else {
            return []
        }
        guard !variableDecl.hasMacroApplication(trackedMacroName) else {
            return []
        }
        guard !variableDecl.hasMacroApplication(ignoredMacroName) else {
            return []
        }
        return [
            AttributeSyntax(attributeName: IdentifierTypeSyntax(name: .identifier(trackedMacroName)))
        ]
    }
}

extension RunestoneObservableMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let identified = declaration.asProtocol(NamedDeclSyntax.self) else {
            return []
        }
        guard identified.is(ClassDeclSyntax.self) else {
            throw DiagnosticsError(diagnostics: [
                Diagnostic(
                    node: declaration,
                    message: RunestoneMacroDiagnostic.onlyApplicableToClass
                )
            ])
        }
        let typeName = identified.name.text
        return [
            try makeObservableRegistrarVariable(forTypeNamed: typeName)
        ]
    }
}

private extension RunestoneObservableMacro {
    private static func makeObservableRegistrarVariable(forTypeNamed typeName: String) throws -> DeclSyntax {
        let syntax = try VariableDeclSyntax(
           """
           private let _observableRegistrar = _RunestoneObservation.ObservableRegistrar()
           """
        )
        return DeclSyntax(syntax)
    }
}
