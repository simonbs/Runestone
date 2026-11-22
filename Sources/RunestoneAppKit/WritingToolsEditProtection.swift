#if canImport(AppKit)
import AppKit

/// Tracks a live system range through accepted UTF-16 edits. A missing or invalid
/// range fails closed until the coordinator supplies a usable context.
struct WritingToolsEditProtection {
    private var reported: NSRange?
    private var tracked: NSRange?

    mutating func range(reported range: NSRange?, documentLength: Int) -> NSRange {
        let whole = NSRange(location: 0, length: documentLength)
        guard let range else { return whole }
        if reported == range, let tracked, Self.valid(tracked, length: documentLength) { return tracked }
        guard Self.valid(range, length: documentLength) else { return whole }
        if reported != range || tracked == nil {
            reported = range
            tracked = range
        }
        guard let tracked, Self.valid(tracked, length: documentLength) else { return whole }
        return tracked
    }

    static func allows(_ edit: NSRange, protecting range: NSRange) -> Bool {
        if edit.length == 0 {
            return edit.location < range.location || edit.location > NSMaxRange(range)
        }
        if range.length == 0 { return !(edit.location <= range.location && NSMaxRange(edit) >= range.location) }
        return NSIntersectionRange(edit, range).length == 0
    }

    mutating func didReplace(_ edit: NSRange, withLength length: Int) {
        guard let range = tracked else { return }
        let delta = length - edit.length
        if edit.length == 0, edit.location >= range.location, edit.location <= NSMaxRange(range) {
            tracked = NSRange(location: range.location, length: range.length + length)
        } else if NSMaxRange(edit) <= range.location {
            tracked = NSRange(location: range.location + delta, length: range.length)
        } else if edit.location < NSMaxRange(range) {
            let start = min(range.location, edit.location)
            let end = max(edit.location + length, NSMaxRange(range) + delta)
            tracked = NSRange(location: start, length: max(0, end - start))
        }
    }

    private static func valid(_ range: NSRange, length: Int) -> Bool {
        range.location >= 0 && range.location <= length && range.length >= 0 && range.length <= length - range.location
    }
}

extension ReadOnlyDocumentView {
    /// Consulted under the input transaction before any text mutation. System
    /// replacements use an explicit route, rather than a global bypass flag.
    public func allowsOrdinaryWritingToolsEdit(in range: NSRange) -> Bool {
        guard isWritingToolsActive else { return true }
        let protected = writingToolsEditProtection.range(reported: writingToolsProtectedRangeProvider?(),
                                                        documentLength: manager.stringView.string.length)
        return WritingToolsEditProtection.allows(range, protecting: protected)
    }

    func allowsWritingToolsEdit(in range: NSRange, isSystemReplacement: Bool) -> Bool {
        let allowed = allowsOrdinaryWritingToolsEdit(in: range)
        if allowed, !isSystemReplacement { cancelWritingToolsReflowAnimation() }
        return isSystemReplacement || allowed
    }

    public func resetWritingToolsEditProtection() {
        writingToolsEditProtection = WritingToolsEditProtection()
    }
}
#endif
