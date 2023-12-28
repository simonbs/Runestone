import SwiftSyntax
import SwiftCompilerPluginMessageHandling
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct RunestoneObservationTrackedMacro {}

extension RunestoneObservationTrackedMacro: AccessorMacro {
    private static let trackedMacroName = "RunestoneObservationTracked"
    private static let ignoredMacroName = "RunestoneObservationIgnored"

    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard let variableDecl = declaration.as(VariableDeclSyntax.self) else {
            return []
        }
        guard let propertyName = variableDecl.identifier?.trimmed.text else {
            return []
        }
        let initSyntax: AccessorDeclSyntax =
           """
           @storageRestrictions(initializes: _\(raw: propertyName))
           init(initialValue) {
               _\(raw: propertyName) = initialValue
           }
           """
        let setSyntax: AccessorDeclSyntax =
           """
           set {
               _observableRegistry.mutating(
                   \\.\(raw: propertyName),
                   on: self,
                   changingFrom: \(raw: propertyName),
                   to: newValue
               ) {
                   _\(raw: propertyName) = newValue
               }
           }
           """
        let getSyntax: AccessorDeclSyntax =
           """
           get {
                _\(raw: propertyName)
           }
           """
        return [initSyntax, setSyntax, getSyntax]
    }
}

extension RunestoneObservationTrackedMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let variableDecl = declaration.as(VariableDeclSyntax.self) else {
            return []
        }
        guard variableDecl.isValidForObservation else {
            return []
        }
        guard !variableDecl.hasMacroApplication(ignoredMacroName) else {
            return []
        }
        guard !variableDecl.hasMacroApplication(trackedMacroName) else {
            return []
        }
        let ignoredAttribute = AttributeSyntax(
            leadingTrivia: .space,
            atSign: .atSignToken(),
            attributeName: IdentifierTypeSyntax(name: .identifier(ignoredMacroName)),
            trailingTrivia: .space
        )
        return [
            DeclSyntax(variableDecl.privatePrefixed("_", addingAttribute: ignoredAttribute))
        ]
    }
}
