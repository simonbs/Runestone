import Foundation

extension ProcessInfo {
    var useCRLFLineEndings: Bool {
        return environment["crlfLineEndings"] != nil
    }
}
