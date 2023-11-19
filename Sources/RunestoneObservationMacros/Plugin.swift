import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct Plugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        RunestoneObservableMacro.self,
        RunestoneObservationTrackedMacro.self,
        RunestoneObservationIgnoredMacro.self,
        RunestoneObserverMacro.self
    ]
}
