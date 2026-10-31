import Foundation

/// Selects the delimiter for an explicitly identified logical newline command.
/// Arbitrary insertion, paste and marked text must remain unchanged.
public enum RunestoneLineEndingPolicy {
    private enum Ending: String, CaseIterable {
        case lf = "\n"
        case crlf = "\r\n"
        case cr = "\r"
        case nextLine = "\u{0085}"
        case lineSeparator = "\u{2028}"
        case paragraphSeparator = "\u{2029}"
    }

    /// Returns a newline for the replacement of `range` in `snapshot`.
    ///
    /// The range is measured in UTF-16 code units. Its endpoints must be scalar
    /// boundaries and may not split a CRLF pair. Invalid ranges return nil.
    /// The nearest delimiters outside the entire replacement are used when they
    /// agree or only one exists. If they disagree, or selection removes every
    /// surrounding delimiter, the unique predominant delimiter in the original
    /// snapshot is used. A tie or a document without delimiters falls back to
    /// LF. CRLF counts as one delimiter; LF, CR, U+0085, U+2028 and U+2029 count as one
    /// each. The snapshot is never modified. Local scans stop at the nearest
    /// delimiters; a document-wide count is needed only for ambiguous context.
    public static func newline(in snapshot: NSString, replacing range: NSRange) -> String? {
        guard range.location >= 0, range.length >= 0, range.location <= snapshot.length,
              range.length <= snapshot.length - range.location else { return nil }
        let end = range.location + range.length
        guard isBoundary(range.location, in: snapshot), isBoundary(end, in: snapshot) else { return nil }
        let before = previousEnding(in: snapshot, before: range.location)
        let after = nextEnding(in: snapshot, from: end)
        switch (before, after) {
        case let (left?, right?) where left == right:
            return left.rawValue
        case let (left?, nil):
            return left.rawValue
        case let (nil, right?):
            return right.rawValue
        case (nil, nil) where range.length == 0:
            return Ending.lf.rawValue
        default:
            return predominantEnding(in: snapshot).rawValue
        }
    }

    private static func isBoundary(_ offset: Int, in text: NSString) -> Bool {
        guard offset > 0, offset < text.length else { return true }
        let previous = text.character(at: offset - 1)
        let next = text.character(at: offset)
        if previous == 0x0D && next == 0x0A { return false }
        return !(0xD800...0xDBFF).contains(previous) || !(0xDC00...0xDFFF).contains(next)
    }

    private static func previousEnding(in text: NSString, before offset: Int) -> Ending? {
        var index = offset
        while index > 0 {
            index -= 1
            switch text.character(at: index) {
            case 0x0A:
                if index > 0 && text.character(at: index - 1) == 0x0D { return .crlf }
                return .lf
            case 0x0D: return .cr
            case 0x0085: return .nextLine
            case 0x2028: return .lineSeparator
            case 0x2029: return .paragraphSeparator
            default: break
            }
        }
        return nil
    }

    private static func nextEnding(in text: NSString, from offset: Int) -> Ending? {
        var index = offset
        while index < text.length {
            switch text.character(at: index) {
            case 0x0D:
                if index + 1 < text.length && text.character(at: index + 1) == 0x0A { return .crlf }
                return .cr
            case 0x0A: return .lf
            case 0x0085: return .nextLine
            case 0x2028: return .lineSeparator
            case 0x2029: return .paragraphSeparator
            default: index += 1
            }
        }
        return nil
    }

    private static func predominantEnding(in text: NSString) -> Ending {
        var counts: [Ending: Int] = [:]
        var index = 0
        while index < text.length {
            let ending: Ending?
            switch text.character(at: index) {
            case 0x0D:
                if index + 1 < text.length && text.character(at: index + 1) == 0x0A {
                    ending = .crlf
                    index += 1
                } else {
                    ending = .cr
                }
            case 0x0A: ending = .lf
            case 0x0085: ending = .nextLine
            case 0x2028: ending = .lineSeparator
            case 0x2029: ending = .paragraphSeparator
            default: ending = nil
            }
            if let ending = ending { counts[ending, default: 0] += 1 }
            index += 1
        }
        let maximum = counts.values.max() ?? 0
        guard maximum > 0 else { return .lf }
        let winners = Ending.allCases.filter { counts[$0, default: 0] == maximum }
        return winners.count == 1 ? winners[0] : .lf
    }
}
