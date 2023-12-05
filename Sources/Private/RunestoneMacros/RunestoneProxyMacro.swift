import SwiftSyntax
import SwiftCompilerPluginMessageHandling
import SwiftSyntaxMacros
import SwiftDiagnostics

public struct RunestoneProxyMacro: AccessorMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax] {
        guard case let .argumentList(argumentList) = node.arguments, let argument = argumentList.first else {
            throw DiagnosticsError(diagnostics: [
                Diagnostic(node: node, message: RunestoneMacroDiagnostic.missingArgument)
            ])
        }
        guard let keyPathExpr = argument.as(LabeledExprSyntax.self)?.expression.as(KeyPathExprSyntax.self) else {
            throw DiagnosticsError(diagnostics: [
                Diagnostic(node: argument, message: RunestoneMacroDiagnostic.notAKeyPath)
            ])
        }
        let getAccessor: AccessorDeclSyntax =
           """
           get {
               return self[keyPath: \(raw: keyPathExpr.description)]
           }
           """
        let setAccessor: AccessorDeclSyntax =
           """
           set {
               self[keyPath: \(raw: keyPathExpr.description)] = newValue
           }
           """
        return [getAccessor, setAccessor]
    }
}
