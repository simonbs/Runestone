#if canImport(AppKit)
import Foundation

/// Identifies one visual caret when a UTF-16 offset has more than one
/// representation. The layout revision prevents an identity captured against
/// one wrapping/directional layout from being reused after that layout changes.
struct InputCaretAffinity: Equatable {
    enum WrapSide: Equatable { case upstream, downstream }
    enum BidirectionalSide: Equatable { case primary, secondary }

    let wrapSide: WrapSide?
    let bidirectionalSide: BidirectionalSide?
    let layoutRevision: UUID
}

/// Selection state shared by mutation, presentation and geometry. NSRange does
/// not identify the active end of an extended selection or either visual caret
/// at a soft-wrap/bidirectional boundary.
struct InputSelectionState: Equatable {
    enum Endpoint: Equatable { case caret, lowerBound, upperBound }

    let range: NSRange
    let activeEndpoint: Endpoint
    let affinity: InputCaretAffinity?

    static func rangeOnly(_ range: NSRange) -> InputSelectionState {
        InputSelectionState(range: range, activeEndpoint: range.length == 0 ? .caret : .upperBound, affinity: nil)
    }

    var activeLocation: Int {
        switch activeEndpoint {
        case .caret, .lowerBound: return range.location
        case .upperBound: return range.upperBound
        }
    }
}

struct InputCaretTarget: Equatable {
    let location: Int
    let affinity: InputCaretAffinity?
}
#endif
