#if canImport(AppKit)
import AppKit

/// Visual word navigation through already-resolved Core Text caret edges.
/// A bounded walk stops rather than guessing across clipped, ambiguous or
/// otherwise unavailable geometry. It never changes the view or selection.
enum PreparedInputVisualWordMovement {
    private static let maximumSteps = 128
    private static let maximumVisibleUnits = 4096
    private static let contextUnits = 2048

    private enum Token {
        case separator
        case symbol
        case word(NSRange)
        case unavailable
    }

    static func destination(from origin: Int, direction: PreparedInputVisualMovement.HorizontalDirection,
                            in view: ReadOnlyDocumentView) -> PreparedInputVisualMovement.HorizontalResult {
        let text = view.manager.stringView.string
        guard !view.isRetired, !view.updatingViewport, origin >= 0, origin <= text.length,
              let layout = view.visibleLayout, layout.isComplete,
              visibleWorkIsBounded(layout), let context = contextRange(around: origin, in: text) else { return .unavailable }
        let contentRevision = view.contentRevision
        let geometryRevision = view.inputGeometryRevision
        let words = wordRanges(in: text, range: context)
        var position = origin
        var crossedSeparator = false

        for step in 0..<maximumSteps {
            guard !view.isRetired, !view.updatingViewport, view.contentRevision == contentRevision,
                  view.inputGeometryRevision == geometryRevision else { return .unavailable }
            let next: Int
            switch PreparedInputVisualMovement.horizontal(from: position, direction: direction, in: view) {
            case .unavailable: return .unavailable
            case .boundary: return crossedSeparator ? .moved(position) : .boundary
            case let .moved(value): next = value
            }
            guard next != position, let traversed = traversedUnit(from: position, to: next, in: text),
                  traversed.location >= context.location, traversed.upperBound <= context.upperBound else { return .unavailable }
            switch token(for: traversed, words: words, context: context, in: text) {
            case .unavailable:
                return .unavailable
            case .separator:
                crossedSeparator = true
                position = next
            case .symbol:
                return .moved(next)
            case let .word(range):
                // A word touching a truncated context edge may continue beyond
                // the inspected range, so its true boundary is unknown.
                if (range.location == context.location && context.location > 0) ||
                    (range.upperBound == context.upperBound && context.upperBound < text.length) { return .unavailable }
                position = next
                if position == range.location || position == range.upperBound { return .moved(position) }
                // Once inside a word, all further visual edges must traverse
                // the same word. Crossing a bidi ambiguity is unavailable.
                return finishWord(range, from: position, direction: direction, in: view, text: text,
                                  context: context, words: words, contentRevision: contentRevision,
                                  geometryRevision: geometryRevision, remaining: maximumSteps - step - 1)
            }
        }
        return .unavailable
    }

    private static func finishWord(_ word: NSRange, from start: Int,
                                   direction: PreparedInputVisualMovement.HorizontalDirection,
                                   in view: ReadOnlyDocumentView, text: NSString, context: NSRange,
                                   words: [NSRange], contentRevision: UUID, geometryRevision: UUID,
                                   remaining: Int) -> PreparedInputVisualMovement.HorizontalResult {
        var position = start
        for _ in 0..<remaining {
            guard !view.isRetired, !view.updatingViewport, view.contentRevision == contentRevision,
                  view.inputGeometryRevision == geometryRevision else { return .unavailable }
            guard case let .moved(next) = PreparedInputVisualMovement.horizontal(from: position, direction: direction, in: view),
                  next != position, let unit = traversedUnit(from: position, to: next, in: text),
                  unit.location >= context.location, unit.upperBound <= context.upperBound else { return .unavailable }
            guard case let .word(nextWord) = token(for: unit, words: words, context: context, in: text),
                  nextWord == word else { return .unavailable }
            position = next
            if position == word.location || position == word.upperBound { return .moved(position) }
        }
        return .unavailable
    }

    /// Reject very large visible fragments before repeated Core Text edge
    /// enumeration; otherwise a single long unwrapped line can be unbounded.
    private static func visibleWorkIsBounded(_ layout: ViewportLayoutCoordinator.Result) -> Bool {
        var units = 0
        for line in layout.lines {
            for placement in line.placements {
                let count = max(placement.fragment.visibleRange.length, placement.fragment.range.length)
                guard count >= 0, count <= maximumVisibleUnits - units else { return false }
                units += count
            }
        }
        return true
    }

    private static func contextRange(around origin: Int, in text: NSString) -> NSRange? {
        var start = origin - min(origin, contextUnits)
        var end = origin + min(text.length - origin, contextUnits)
        if start > 0 && start < text.length {
            start = text.rangeOfComposedCharacterSequence(at: start).location
            if start > 0 && text.character(at: start - 1) == 0x0D && text.character(at: start) == 0x0A { start -= 1 }
        }
        if end > 0 && end < text.length {
            let cluster = text.rangeOfComposedCharacterSequence(at: end)
            if cluster.location < end { end = cluster.upperBound }
            if end < text.length && text.character(at: end - 1) == 0x0D && text.character(at: end) == 0x0A { end += 1 }
        }
        guard start >= 0, end >= start, end <= text.length,
              end - start <= contextUnits * 2 + 2 else { return nil }
        return NSRange(location: start, length: end - start)
    }

    private static func wordRanges(in text: NSString, range: NSRange) -> [NSRange] {
        guard range.length > 0 else { return [] }
        var ranges: [NSRange] = []
        text.enumerateSubstrings(in: range, options: [.byWords, .substringNotRequired]) { _, range, _, _ in
            ranges.append(range)
        }
        return ranges
    }

    /// A visual step is safe only when it crosses exactly one complete
    /// composed sequence or the complete CRLF delimiter.
    private static func traversedUnit(from: Int, to: Int, in text: NSString) -> NSRange? {
        let start = min(from, to), end = max(from, to)
        guard start >= 0, start < end, end <= text.length else { return nil }
        if end - start == 2, text.character(at: start) == 0x0D, text.character(at: start + 1) == 0x0A {
            return NSRange(location: start, length: 2)
        }
        guard !(start > 0 && text.character(at: start - 1) == 0x0D && text.character(at: start) == 0x0A),
              !(end < text.length && text.character(at: end - 1) == 0x0D && text.character(at: end) == 0x0A) else { return nil }
        let cluster = text.rangeOfComposedCharacterSequence(at: start)
        return cluster.location == start && cluster.upperBound == end ? cluster : nil
    }

    private static func token(for unit: NSRange, words: [NSRange], context: NSRange, in text: NSString) -> Token {
        let symbol = (text.substring(with: unit) as NSString).rangeOfCharacter(from: .symbols).location != NSNotFound
        if symbol { return .symbol }
        for word in words {
            if word.location <= unit.location && unit.upperBound <= word.upperBound { return .word(word) }
            if NSIntersectionRange(unit, word).length > 0 { return .unavailable }
        }
        // Do not silently skip a lexical character that Foundation could not
        // classify as a full word in the inspected context.
        let lexical = CharacterSet.alphanumerics.union(.nonBaseCharacters)
        if (text.substring(with: unit) as NSString).rangeOfCharacter(from: lexical).location != NSNotFound {
            return .unavailable
        }
        return .separator
    }
}
#endif
