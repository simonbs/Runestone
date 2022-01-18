import Foundation

/// Multiple ranges of the text in a text view to be replaced with a string.
///
/// When replacing text in batches, Runestone can do some optimizations to make the operation faster than when replacing the ranges one by one.
///
/// Replacing a batch of matches will only register a single undo operation.
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
