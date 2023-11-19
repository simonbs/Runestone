import SwiftDiagnostics

enum ProxyMacroDiagnostic: String, DiagnosticMessage {
    case missingArgument
    case notAKeyPath

    var severity: DiagnosticSeverity {
        .error
    }
    var diagnosticID: MessageID {
        MessageID(domain: "ExperimentsMacros", id: rawValue)
    }
    var message: String {
        switch self {
        case .missingArgument:
            "Please supply a key path as argument."
        case .notAKeyPath:
            "Supplied argument must be a key path."
        }
    }
}
