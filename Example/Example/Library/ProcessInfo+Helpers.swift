import Foundation

extension ProcessInfo {
    var disableTextPersistance: Bool {
        return environment["disableTextPersistance"] != nil
    }
}
