import Foundation

struct HighlightRangeSlice: Equatable {
    let range: NSRange
    let containsStart: Bool
    let containsEnd: Bool

    func clipped(to bounds: NSRange, localize: Bool = false) -> Self? {
        guard range.overlaps(bounds) else {
            return nil
        }
        let clippedRange = range.capped(to: bounds)
        return Self(range: localize ? clippedRange.local(to: bounds) : clippedRange,
                    containsStart: containsStart && clippedRange.lowerBound == range.lowerBound,
                    containsEnd: containsEnd && clippedRange.upperBound == range.upperBound)
    }
}
