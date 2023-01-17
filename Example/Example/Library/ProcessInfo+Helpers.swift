import Foundation

extension ProcessInfo {
    var disableTextPersistance: Bool {
        return environment["disableTextPersistance"] != nil
    }

    var useCRLFLineEndings: Bool {
        return environment["crlfLineEndings"] != nil
    }
}
