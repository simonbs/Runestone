import Foundation

/// An optional fast-path span whose boundaries are expressed in UTF-16 units.
public struct LineTypesetterRun {
    /// How an admitted cluster-width break is adjusted before fragment creation.
    public enum BreakStrategy: Equatable {
        /// Preserve the cluster break exactly.
        case character
        /// Use bounded native word breaking around the cluster-width result.
        case word
    }

    /// The admitted UTF-16 span.
    public let range: Range<Int>
    /// Whether the fast path may begin at the span’s lower bound.
    public let allowsInitialOffset: Bool
    /// The bounded adjustment applied to cluster-width results inside this run.
    public let breakStrategy: BreakStrategy

    /// Creates an admitted span and its initial-offset policy.
    public init(range: Range<Int>, allowsInitialOffset: Bool, breakStrategy: BreakStrategy = .character) {
        self.range = range
        self.allowsInitialOffset = allowsInitialOffset
        self.breakStrategy = breakStrategy
    }
}

/// Prepared text and the optional fast-path span admitted by a platform policy.
public struct PreparedLineTypesetterInput {
    /// Immutable prepared text used by Core Text.
    public let text: NSAttributedString
    /// Span eligible for the fast line-break path.
    public let run: LineTypesetterRun

    /// Creates a prepared input and its admitted span.
    public init(text: NSAttributedString, run: LineTypesetterRun) {
        self.text = text
        self.run = run
    }
}

/// Platform-owned preparation and optimization policy for Core Text typesetting.
public protocol LineTypesetterPreparation {
    /// Returns an optimized input when the platform can safely admit one.
    func prepare(_ input: NSAttributedString) -> PreparedLineTypesetterInput?
    /// Returns the number of existing fragments safe to reuse for an edit.
    func reusablePrefixCount(from old: NSAttributedString, to new: NSAttributedString,
                             fragments: [LineFragment], limit: Int) -> Int
    /// Produces the attributed string passed to Core Text for drawing runs.
    func stringForTypesetting(_ input: NSAttributedString) -> NSAttributedString
}

/// Uses ordinary Core Text line breaking without platform-specific optimizations.
public struct DefaultLineTypesetterPreparation: LineTypesetterPreparation {
    /// Platform background attribute to map into the separate drawing pass, if any.
    public var backgroundColorKey: NSAttributedString.Key?

    /// Creates a default policy, optionally mapping a platform background key.
    public init(backgroundColorKey: NSAttributedString.Key? = nil) {
        self.backgroundColorKey = backgroundColorKey
    }

    public func prepare(_ input: NSAttributedString) -> PreparedLineTypesetterInput? { nil }

    public func reusablePrefixCount(from old: NSAttributedString, to new: NSAttributedString,
                                    fragments: [LineFragment], limit: Int) -> Int { 0 }

    public func stringForTypesetting(_ input: NSAttributedString) -> NSAttributedString {
        guard let backgroundColorKey else { return input }
        return TokenBackgroundMapping.stringForTypesetting(input, backgroundColorKey: backgroundColorKey)
    }
}
