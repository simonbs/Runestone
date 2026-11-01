import Foundation

struct SpellingParagraphSnapshot: Equatable {
    let range: NSRange
    let text: String
}

/// Find paragraph boundaries only inside bounded neighborhoods. NSString's paragraph/composed-range
/// expansion on the original document could scan an entire unwrapped line or huge combining sequence.
struct SpellingParagraphSnapshotBuilder {
    let text: NSString
    private var result: [SpellingParagraphSnapshot] = []
    private var remaining = 16_384
    private var scans = 32_768

    init(text: NSString) {
        self.text = text
    }

    mutating func snapshots(visibleRanges: [NSRange]) -> [SpellingParagraphSnapshot] {
        // Empty-line and overlapping-window inputs consume the scan budget even if they produce no samples.
        for visible in visibleRanges.prefix(64) where visible.location >= 0 && visible.length > 0
            && visible.location <= text.length && visible.length <= text.length - visible.location {
            var cursor = visible.location
            while cursor < NSMaxRange(visible), remaining > 0, scans > 0, result.count < 16 {
                scans -= 1
                if let existing = result.first(where: { NSLocationInRange(cursor, $0.range) }) {
                    cursor = NSMaxRange(existing.range)
                    continue
                }
                let sample = capture(at: cursor)
                if let snapshot = sample.snapshot {
                    result.append(snapshot)
                    remaining -= snapshot.range.length
                }
                cursor = sample.next
            }
            if remaining == 0 || scans == 0 || result.count == 16 { break }
        }
        return result
    }

    private mutating func capture(at cursor: Int) -> (snapshot: SpellingParagraphSnapshot?, next: Int) {
        let lower = max(0, cursor - min(remaining, 2_048) / 2)
        var start = cursor
        while start > lower, scans > 0, !Self.isParagraphSeparator(text.character(at: start - 1)) {
            start -= 1
            scans -= 1
        }
        for previous in result where previous.range.location <= cursor && NSMaxRange(previous.range) > start {
            start = NSMaxRange(previous.range)
        }
        var end = cursor
        let upper = min(text.length, start + min(remaining, 2_048))
        while end < upper, scans > 0, !Self.isParagraphSeparator(text.character(at: end)) {
            end += 1
            scans -= 1
        }
        let next = max(cursor + 1, end + 1)
        guard let range = clippedRange(start: start, end: end) else {
            return (nil, next)
        }
        return (SpellingParagraphSnapshot(range: range, text: text.substring(with: range)), next)
    }

    private mutating func clippedRange(start: Int, end: Int) -> NSRange? {
        var start = start
        var end = end
        // ASCII whitespace followed by an ASCII letter/digit is an unambiguous grapheme/word
        // boundary. Other clipped scripts conservatively skip detection if none fits within the cap.
        if start > 0, !Self.isParagraphSeparator(text.character(at: start - 1)) {
            while start < end, scans > 0, !isClippedBoundary(at: start) {
                start += 1
                scans -= 1
            }
        }
        if end < text.length, !Self.isParagraphSeparator(text.character(at: end)) {
            while end > start, scans > 0, !isClippedBoundary(at: end) {
                end -= 1
                scans -= 1
            }
        }
        guard scans > 0, end > start else {
            return nil
        }
        return NSRange(location: start, length: end - start)
    }

    private func isClippedBoundary(at index: Int) -> Bool {
        guard index > 0, index < text.length else {
            return false
        }
        let previous = text.character(at: index - 1)
        let next = text.character(at: index)
        return (previous == 9 || previous == 32)
            && ((65...90).contains(next) || (97...122).contains(next) || (48...57).contains(next))
    }

    private static func isParagraphSeparator(_ unit: unichar) -> Bool {
        unit == 10 || unit == 13 || unit == 0x2028 || unit == 0x2029
    }
}
