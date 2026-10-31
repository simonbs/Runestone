#if canImport(AppKit)
import AppKit

final class PreparedInputTextCheckingAnnotations {
    private struct Entry { var range: NSRange; var values: [NSAttributedString.Key: String] }
    private var entries: [Entry] = []

    func apply(to text: NSMutableAttributedString, documentRange: NSRange) {
        for entry in entries {
            let overlap = NSIntersectionRange(entry.range, documentRange)
            guard overlap.length > 0 else { continue }
            text.addAttributes(entry.values, range: NSRange(location: overlap.location - documentRange.location,
                                                             length: overlap.length))
        }
    }

    func set(_ values: [NSAttributedString.Key: String], range: NSRange, textLength: Int) {
        guard let range = Self.clamp(range, textLength: textLength), range.length > 0 else { return }
        entries.removeAll { NSIntersectionRange($0.range, range).length > 0 }
        if !values.isEmpty { entries.append(Entry(range: range, values: values)) }
    }

    func add(_ values: [NSAttributedString.Key: String], range: NSRange, textLength: Int) {
        guard let range = Self.clamp(range, textLength: textLength), range.length > 0, !values.isEmpty else { return }
        entries.append(Entry(range: range, values: values))
    }

    func remove(_ key: NSAttributedString.Key, range: NSRange, textLength: Int) {
        guard let range = Self.clamp(range, textLength: textLength) else { return }
        for index in entries.indices where NSIntersectionRange(entries[index].range, range).length > 0 {
            entries[index].values.removeValue(forKey: key)
        }
        entries.removeAll { $0.values.isEmpty }
    }

    func removeAll() { entries.removeAll() }

    static func clamp(_ range: NSRange, textLength: Int) -> NSRange? {
        if range.location == NSNotFound { return NSRange(location: 0, length: textLength) }
        guard range.location >= 0, range.length >= 0, range.location <= textLength else { return nil }
        return NSRange(location: range.location, length: min(range.length, textLength - range.location))
    }
}
#endif
