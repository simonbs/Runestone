import Foundation

enum WritingToolsExclusions {
    /// Finds the smallest contiguous update containing an edit and changed exclusion attributes.
    /// Inputs must describe a valid edit and normalized exclusions in the old and new documents.
    /// Comparing intervals keeps the cost proportional to exclusions, not document length.
    static func updateRanges(replacing range: NSRange, withLength replacementLength: Int, oldLength: Int,
                             oldExcludedRanges: [NSRange], newExcludedRanges: [NSRange]) -> (old: NSRange, new: NSRange) {
        let delta = replacementLength - range.length
        let newEnd = range.location + replacementLength
        var boundaries = [0, oldLength, range.location, NSMaxRange(range)]
        boundaries += oldExcludedRanges.flatMap { [$0.location, NSMaxRange($0)] }
        for boundary in newExcludedRanges.flatMap({ [$0.location, NSMaxRange($0)] }) {
            if boundary <= range.location {
                boundaries.append(boundary)
            } else if boundary >= newEnd {
                boundaries.append(boundary - delta)
            }
        }
        boundaries = Array(Set(boundaries)).sorted()
        var start = range.location
        var end = NSMaxRange(range)
        var oldIndex = 0
        var newIndex = 0
        for (lower, upper) in zip(boundaries, boundaries.dropFirst()) {
            // Attributes inside the replacement are already included in the text update.
            if lower < NSMaxRange(range) && upper > range.location { continue }
            let mapped = lower < range.location ? lower : lower + delta
            while oldIndex < oldExcludedRanges.count && NSMaxRange(oldExcludedRanges[oldIndex]) <= lower {
                oldIndex += 1
            }
            while newIndex < newExcludedRanges.count && NSMaxRange(newExcludedRanges[newIndex]) <= mapped {
                newIndex += 1
            }
            let wasExcluded = oldIndex < oldExcludedRanges.count && oldExcludedRanges[oldIndex].location <= lower
            let isExcluded = newIndex < newExcludedRanges.count && newExcludedRanges[newIndex].location <= mapped
            if wasExcluded != isExcluded {
                start = min(start, lower)
                end = max(end, upper)
            }
        }
        return (NSRange(location: start, length: end - start),
                NSRange(location: start, length: end - start + delta))
    }

    static func normalizedRanges(_ ranges: [NSRange], in text: NSString) -> [NSRange] {
        let sorted = ranges.filter { $0.length > 0 && WritingToolsRange.isValid($0, in: text) }
            .sorted { $0.location < $1.location }
        var result: [NSRange] = []
        for range in sorted {
            if let previous = result.last, NSMaxRange(previous) >= range.location {
                result[result.count - 1].length = max(NSMaxRange(previous), NSMaxRange(range)) - previous.location
            } else {
                result.append(range)
            }
        }
        return result
    }

    /// Ignore unchanged prefixes/suffixes in a replacement that includes protected text.
    /// A protected island inside a larger changed span cannot be mapped unambiguously;
    /// reject that replacement instead of risking a change to its contents.
    static func allowsReplacement(in range: NSRange, with replacement: String,
                                  in text: NSString, excluding excludedRanges: [NSRange]) -> Bool {
        guard WritingToolsRange.isValid(range, in: text) else {
            return false
        }
        guard !excludedRanges.isEmpty else {
            return true
        }
        let original = text.substring(with: range) as NSString
        let replacement = replacement as NSString
        var prefix = 0
        while prefix < min(original.length, replacement.length),
              original.character(at: prefix) == replacement.character(at: prefix) {
            prefix += 1
        }
        if prefix == original.length && prefix == replacement.length {
            return true
        }
        // Matching UTF-16 code units must not trim half of a supplementary character.
        while prefix > 0 && (!WritingToolsRange.isValid(NSRange(location: prefix, length: 0), in: original)
            || !WritingToolsRange.isValid(NSRange(location: prefix, length: 0), in: replacement)) {
            prefix -= 1
        }
        var suffix = 0
        while suffix < min(original.length, replacement.length) - prefix,
              original.character(at: original.length - suffix - 1) == replacement.character(at: replacement.length - suffix - 1) {
            suffix += 1
        }
        while suffix > 0 && (!WritingToolsRange.isValid(NSRange(location: original.length - suffix, length: 0), in: original)
            || !WritingToolsRange.isValid(NSRange(location: replacement.length - suffix, length: 0), in: replacement)) {
            suffix -= 1
        }
        let changed = NSRange(location: range.location + prefix, length: range.length - prefix - suffix)
        return !excludedRanges.contains { excluded in
            if changed.length == 0 {
                return changed.location > excluded.location && changed.location < NSMaxRange(excluded)
            }
            return NSIntersectionRange(changed, excluded).length > 0
        }
    }
}
