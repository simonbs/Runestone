import Foundation

public struct BatchReplaceSet: Hashable {
    public struct Match: Hashable {
        public let range: NSRange
        public let replacementText: String

        public init(range: NSRange, replacementText: String) {
            self.range = range
            self.replacementText = replacementText
        }
    }

    public let matches: [Match]

    public init(matches: [Match]) {
        self.matches = matches
    }
}
