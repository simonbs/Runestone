import SwiftDiagnostics

enum RunestoneMacroDiagnostic: String, DiagnosticMessage {
    case onlyApplicableToClass

    var severity: DiagnosticSeverity {
        .error
    }
    var diagnosticID: MessageID {
        MessageID(domain: "RunestoneObservationMacros", id: rawValue)
    }
    var message: String {
        switch self {
        case .onlyApplicableToClass:
            "The macro can only be applied to classes."
        }
    }
}
