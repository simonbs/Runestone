import Foundation

extension ProcessInfo {
    var useCRLFLineEndings: Bool {
        environment["crlfLineEndings"] != nil
    }
}
