import Foundation

extension ProcessInfo {
    var useSpellChecking: Bool {
        arguments.contains("--spell-checking")
    }

    var useCRLFLineEndings: Bool {
        environment["crlfLineEndings"] != nil
    }
}
