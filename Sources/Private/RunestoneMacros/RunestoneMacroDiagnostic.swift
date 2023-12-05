import SwiftDiagnostics

enum RunestoneMacroDiagnostic: String, DiagnosticMessage {
    case missingArgument
    case notAKeyPath
    case onlyApplicableToClass

    var severity: DiagnosticSeverity {
        .error
    }
    var diagnosticID: MessageID {
        MessageID(domain: "RunestonenMacros", id: rawValue)
    }
    var message: String {
        switch self {
        case .missingArgument:
            "Please supply a key path as argument."
        case .notAKeyPath:
            "Supplied argument must be a key path."
        case .onlyApplicableToClass:
            "The macro can only be applied to classes."
        }
    }
}
