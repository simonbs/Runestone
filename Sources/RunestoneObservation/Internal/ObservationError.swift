import Foundation

enum ObservationError: LocalizedError {
    case mismatchOldValueType(expectedType: Any.Type, actualType: Any.Type)
    case mismatchNewValueType(expectedType: Any.Type, actualType: Any.Type)

    var errorDescription: String? {
        switch self {
        case .mismatchOldValueType(let expectedType, let actualType):
            return "Receieved old value of unexpected type \(actualType) but expected \(expectedType)"
        case .mismatchNewValueType(let expectedType, let actualType):
            return "Receieved new value of unexpected type \(actualType) but expected \(expectedType)"
        }
    }
}
