import Foundation

struct AnyObservationChangeHandler {
    private enum ObservationError: LocalizedError {
        case mismatchOldValueType(expectedType: Any.Type, actualType: Any.Type)
        case mismatchNewValueType(expectedType: Any.Type, actualType: Any.Type)

        var errorDescription: String? {
            switch self {
            case .mismatchOldValueType(let expectedType, let actualType):
                "Receieved old value of unexpected type \(actualType) but expected \(expectedType)"
            case .mismatchNewValueType(let expectedType, let actualType):
                "Receieved new value of unexpected type \(actualType) but expected \(expectedType)"
            }
        }
    }

    private let handler: (Any, Any) throws -> Void

    init<T>(_ handler: @escaping (T, T) -> Void) {
        self.handler = { oldValue, newValue in
            guard let typedOldValue = oldValue as? T else {
                throw ObservationError.mismatchOldValueType(
                    expectedType: T.self,
                    actualType: type(of: oldValue)
                )
            }
            guard let typedNewValue = newValue as? T else {
                throw ObservationError.mismatchNewValueType(
                    expectedType: T.self, 
                    actualType: type(of: newValue)
                )
            }
            handler(typedOldValue, typedNewValue)
        }
    }

    func invoke(changingFrom oldValue: Any, to newValue: Any) throws {
        try handler(oldValue, newValue)
    }
}
