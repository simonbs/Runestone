import SwiftSyntax
import SwiftCompilerPluginMessageHandling
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct RunestoneObservationTrackedMacro: AccessorMacro {
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
        let willSetSyntax: AccessorDeclSyntax =
           """
           willSet {
                _observableRegistry.publishChange(
                    ofType: .willSet,
                    changing: \\.\(raw: propertyName),
                    on: self,
                    from: \(raw: propertyName),
                    to: newValue
                )
           }
           """
        let didSetSyntax: AccessorDeclSyntax =
           """
           didSet {
                _observableRegistry.publishChange(
                    ofType: .didSet,
                    changing: \\.\(raw: propertyName),
                    on: self,
                    from: oldValue,
                    to: \(raw: propertyName)
                )
           }
           """
        return [willSetSyntax, didSetSyntax]
    }
}
