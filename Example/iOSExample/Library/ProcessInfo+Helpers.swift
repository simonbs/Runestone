import Foundation

extension ProcessInfo {
    var disableTextPersistance: Bool {
        environment["disableTextPersistance"] != nil
    }

    var useCRLFLineEndings: Bool {
        environment["crlfLineEndings"] != nil
    }
}
