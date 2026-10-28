import CoreText
import Foundation
import UIKit

/// Validates a one-shot text edit against already measured geometry. Nothing is
/// cached or scanned on cold preparation; drawing runs are always rebuilt later.
enum LinePrefixReuse {
    private struct Signature: Equatable {
        let font: UIFont
        let paragraph: NSParagraphStyle
    }

    static func count(from old: NSAttributedString, to new: NSAttributedString,
                      fragments: [LineFragment], limit: Int) -> Int {
        let limit = min(limit, fragments.count)
        // Conservative cutoff, not a measured crossover. Small/early viewport
        // requests should not scan two full paragraphs to save a few line breaks.
        guard limit > 1, fragments[limit - 1].range.upperBound >= 4_096,
              old.length > 0, new.length > 0, terminalLength(old) == terminalLength(new) else {
            return 0
        }
        let count: Int
        if let change = firstChange(old, new) {
            let oldRestart = restart(in: old, at: change)
            guard oldRestart > 0 else {
                return 0
            }
            let restart = min(oldRestart, restart(in: new, at: change))
            let eligible = fragments.prefix { $0.range.upperBound <= restart }.count
            // Reflow the affected token, preceding spaces, and one guard fragment.
            count = min(limit, max(0, eligible - 1))
        } else {
            count = limit
        }
        // Near-start changes cannot benefit, even when the requested region is
        // deep. Reject before full character/attribute scans or canonical setup.
        guard count > 1, fragments[count - 1].range.upperBound >= 4_096,
              let oldSignature = signature(old), let newSignature = signature(new),
              oldSignature == newSignature, isPrintableASCII(old), isPrintableASCII(new) else {
            return 0
        }
        return count
    }

    private static func signature(_ text: NSAttributedString) -> Signature? {
        let first = text.attributes(at: 0, effectiveRange: nil)
        guard let font = first[.font] as? UIFont,
              let ordinary = UIFont(name: "Menlo-Regular", size: font.pointSize),
              font == ordinary || font == DefaultTheme.shared.font,
              let paragraph = first[.paragraphStyle] as? NSParagraphStyle,
              isStandardParagraph(paragraph) else {
            return nil
        }
        // Canonical font/paragraph construction is independent of color-run
        // count. Every later run must match this validated shaping signature.
        let allowed: Set<NSAttributedString.Key> = [.font, .foregroundColor, .backgroundColor, .kern, .ligature, .paragraphStyle]
        var supported = true
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length)) { attributes, _, stop in
            guard attributes.keys.allSatisfy(allowed.contains),
                  attributes[.foregroundColor] is UIColor,
                  attributes[.backgroundColor] == nil || attributes[.backgroundColor] is UIColor,
                  (attributes[.font] as? UIFont) == font,
                  (attributes[.paragraphStyle] as? NSParagraphStyle) == paragraph,
                  attributes[.ligature] == nil || (attributes[.ligature] as? NSNumber)?.doubleValue == 1,
                  (attributes[.kern] as? NSNumber)?.doubleValue == 0 else {
                supported = false
                stop.pointee = true
                return
            }
        }
        return supported ? Signature(font: font, paragraph: paragraph) : nil
    }

    private static func isStandardParagraph(_ paragraph: NSParagraphStyle) -> Bool {
        let interval = paragraph.defaultTabInterval
        guard interval.isFinite, interval > 0 else {
            return false
        }
        let expected = NSMutableParagraphStyle()
        expected.defaultTabInterval = interval
        expected.tabStops = (0 ..< 20).map { NSTextTab(textAlignment: .natural, location: CGFloat($0) * interval) }
        return paragraph == expected
    }

    private static func isPrintableASCII(_ text: NSAttributedString) -> Bool {
        let string = CFAttributedStringGetString(text)
        defer { withExtendedLifetime(string) {} }
        let bodyLength = text.length - terminalLength(text)
        // ASCII bytes have the same indices as UTF-16 units. This API returns
        // existing storage in constant time or nil; never convert/copy here.
        if let bytes = CFStringGetCStringPtr(string, CFStringBuiltInEncodings.ASCII.rawValue) {
            for index in 0 ..< bodyLength {
                guard (32 ... 126).contains(bytes[index]) else {
                    return false
                }
            }
            return true
        }
        let pointer = CFStringGetCharactersPtr(string)
        for index in 0 ..< bodyLength {
            let unit = pointer?[index] ?? CFStringGetCharacterAtIndex(string, index)
            guard (32 ... 126).contains(unit) else {
                return false
            }
        }
        return true
    }

    private static func firstChange(_ old: NSAttributedString, _ new: NSAttributedString) -> Int? {
        let oldString = CFAttributedStringGetString(old)
        let newString = CFAttributedStringGetString(new)
        defer { withExtendedLifetime((oldString, newString)) {} }
        let commonLength = min(old.length, new.length)
        if let oldBytes = CFStringGetCStringPtr(oldString, CFStringBuiltInEncodings.ASCII.rawValue),
           let newBytes = CFStringGetCStringPtr(newString, CFStringBuiltInEncodings.ASCII.rawValue) {
            // Explicit lengths also compare bytes after embedded NUL characters.
            for index in 0 ..< commonLength where oldBytes[index] != newBytes[index] {
                return index
            }
            return old.length == new.length ? nil : commonLength
        }
        let oldPointer = CFStringGetCharactersPtr(oldString)
        let newPointer = CFStringGetCharactersPtr(newString)
        for index in 0 ..< commonLength {
            let oldUnit = oldPointer?[index] ?? CFStringGetCharacterAtIndex(oldString, index)
            let newUnit = newPointer?[index] ?? CFStringGetCharacterAtIndex(newString, index)
            if oldUnit != newUnit {
                return index
            }
        }
        return old.length == new.length ? nil : min(old.length, new.length)
    }

    private static func restart(in text: NSAttributedString, at location: Int) -> Int {
        let string = CFAttributedStringGetString(text)
        defer { withExtendedLifetime(string) {} }
        var start = min(location, text.length - terminalLength(text))
        if let bytes = CFStringGetCStringPtr(string, CFStringBuiltInEncodings.ASCII.rawValue) {
            while start > 0 && bytes[start - 1] == 32 { start -= 1 }
            while start > 0 && bytes[start - 1] != 32 { start -= 1 }
            return start
        }
        while start > 0 && CFStringGetCharacterAtIndex(string, start - 1) == 32 { start -= 1 }
        while start > 0 && CFStringGetCharacterAtIndex(string, start - 1) != 32 { start -= 1 }
        return start
    }

    private static func terminalLength(_ text: NSAttributedString) -> Int {
        let string = CFAttributedStringGetString(text)
        guard text.length > 0, CFStringGetCharacterAtIndex(string, text.length - 1) == 10 else {
            return 0
        }
        return text.length > 1 && CFStringGetCharacterAtIndex(string, text.length - 2) == 13 ? 2 : 1
    }
}
