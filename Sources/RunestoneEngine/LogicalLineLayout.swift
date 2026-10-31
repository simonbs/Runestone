import CoreGraphics
import Foundation

/// An incremental layout target in logical-line coordinates.
public enum LogicalLineLayoutRequest {
    /// Typeset until the bottom of the line-local rectangle is covered.
    case inRect(CGRect)
    /// Typeset through the UTF-16 location and one additional fragment.
    case toLocation(Int)
    /// Typeset through the zero-based fragment index.
    case toLineFragmentIndex(Int)
}

public extension LineTypesetter {
    /// Returns the number of existing fragments strictly before a request target.
    /// This leaves the target-crossing fragment to the normal layout path.
    func reusablePrefixLimit(for request: LogicalLineLayoutRequest) -> Int {
        switch request {
        case .inRect(let rect):
            return lineFragments.prefix { $0.yPosition + $0.scaledSize.height < rect.maxY }.count
        case .toLocation(let location):
            return lineFragments.prefix { $0.range.upperBound < location }.count
        case .toLineFragmentIndex(let index):
            return min(max(0, index), lineFragments.count)
        }
    }

    /// Advances incremental layout to a target, returning newly created fragments.
    @discardableResult
    func typeset(_ request: LogicalLineLayoutRequest) -> [LineFragment] {
        switch request {
        case .inRect(let rect):
            return typesetLineFragments(in: rect)
        case .toLocation(let location):
            return typesetLineFragments(toLocation: location, additionalLineFragmentCount: 1)
        case .toLineFragmentIndex(let index):
            let additionalCount = index < lineFragments.count ? 0 : (index - lineFragments.count == Int.max ? Int.max : index - lineFragments.count + 1)
            return typesetLineFragments(toLocation: 0, additionalLineFragmentCount: additionalCount)
        }
    }

    /// Estimates logical-line height from measured fragments and a fallback height.
    /// Empty and not-yet-measured lines occupy one estimated fragment.
    func estimatedLineHeight(fragmentHeight: CGFloat) -> CGFloat {
        let estimatedHeight = fragmentHeight * lineFragmentHeightMultiplier
        guard let last = lineFragments.last else { return estimatedHeight }
        let knownHeight = last.yPosition + last.scaledSize.height
        let remaining = bestGuessNumberOfLineFragments - lineFragments.count
        return knownHeight + CGFloat(remaining) * estimatedHeight
    }
}
