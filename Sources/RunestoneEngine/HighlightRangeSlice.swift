import Foundation

/// A UTF-16 highlight range and the original endpoints it still contains.
public struct HighlightRangeSlice: Equatable {
    public let range: NSRange
    public let containsStart: Bool
    public let containsEnd: Bool

    public init(range: NSRange, containsStart: Bool, containsEnd: Bool) {
        self.range = range
        self.containsStart = containsStart
        self.containsEnd = containsEnd
    }

    /// Clips the slice to half-open bounds, optionally expressing it relative to them.
    public func clipped(to bounds: NSRange, localize: Bool = false) -> Self? {
        guard (range.lowerBound ..< range.upperBound).overlaps(bounds.lowerBound ..< bounds.upperBound) else {
            return nil
        }
        let lowerBound = max(range.lowerBound, bounds.lowerBound)
        let upperBound = min(range.upperBound, bounds.upperBound)
        let clippedRange = NSRange(location: localize ? lowerBound - bounds.lowerBound : lowerBound,
                                   length: upperBound - lowerBound)
        return Self(range: clippedRange,
                    containsStart: containsStart && lowerBound == range.lowerBound,
                    containsEnd: containsEnd && upperBound == range.upperBound)
    }
}
