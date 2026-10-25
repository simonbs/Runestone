import Foundation

enum WritingToolsRange {
    /// Smallest contiguous UTF-16 change, widened to avoid splitting surrogate pairs.
    static func change(from old: NSString, to new: NSString) -> (range: NSRange, text: String)? {
        guard old != new else {
            return nil
        }
        var start = 0
        while start < min(old.length, new.length), old.character(at: start) == new.character(at: start) { start += 1 }
        while start > 0 && (!isValid(NSRange(location: start, length: 0), in: old)
                            || !isValid(NSRange(location: start, length: 0), in: new)) { start -= 1 }
        var oldEnd = old.length
        var newEnd = new.length
        while oldEnd > start, newEnd > start, old.character(at: oldEnd - 1) == new.character(at: newEnd - 1) {
            oldEnd -= 1
            newEnd -= 1
        }
        while !isValid(NSRange(location: oldEnd, length: 0), in: old)
            || !isValid(NSRange(location: newEnd, length: 0), in: new) {
            oldEnd += 1
            newEnd += 1
        }
        return (NSRange(location: start, length: oldEnd - start),
                new.substring(with: NSRange(location: start, length: newEnd - start)))
    }

    static func isValid(_ range: NSRange, in string: NSString) -> Bool {
        guard range.location >= 0, range.length >= 0, range.location <= string.length,
              range.length <= string.length - range.location else {
                  return false
              }
        // UTF-16 offsets may separate composed characters, but must never split a surrogate pair.
        for offset in [range.location, range.location + range.length] where offset > 0 && offset < string.length {
            let previous = string.character(at: offset - 1)
            let next = string.character(at: offset)
            if (0xD800...0xDBFF).contains(previous) && (0xDC00...0xDFFF).contains(next) {
                return false
            }
        }
        return true
    }
}
