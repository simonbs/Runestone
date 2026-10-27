import Foundation

extension ProcessInfo {
    var disableTextPersistance: Bool {
        environment["disableTextPersistance"] != nil || navigationDocumentName != nil
    }

    /// A UTF-8 fixture in the example app's Documents directory.
    var navigationDocumentName: String? {
        environment["RUNESTONE_DOCUMENT"]
    }

    var useCRLFLineEndings: Bool {
        environment["crlfLineEndings"] != nil
    }
}
