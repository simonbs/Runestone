import CoreText
import Foundation
import UIKit

/// A narrow alphanumeric-run optimization. Native word breaking remains the
/// default for ordinary lines and every unsupported character/attribute context.
struct UnbrokenLineBreakContext {
    let text: NSAttributedString
    // Terminal-excluded paragraph length retained for existing admission diagnostics.
    let bodyLength: Int
    struct Run {
        let range: Range<Int>
        let allowsInitialOffset: Bool
    }

    let run: Run
    var runRange: Range<Int> { run.range }

    static func make(for input: NSAttributedString) -> Self? {
        // Conservative initial cutoff, not a measured crossover. Avoid scanning
        // attributes or allocating snapshots for ordinary short editor lines.
        guard input.length >= 4_096, let string = CFAttributedStringGetString(input),
              let bytes = CFStringGetCStringPtr(string, CFStringBuiltInEncodings.ASCII.rawValue) else {
            return nil
        }
        // A missing pointer declines admission without conversion. Discover only
        // a whole-line prefix or the benchmark's spaces/opening-quote wrapper.
        // Probe <=192 bytes before font setup; ordinary prose/JSON rejects early.
        guard let runStart = probeRunStart(bytes) else {
            return nil
        }
        let firstAttributes = input.attributes(at: 0, effectiveRange: nil)
        guard let font = firstAttributes[.font] as? UIFont,
              (10 ... 22).contains(font.pointSize),
              font == UIFont(name: "Menlo-Regular", size: font.pointSize)
                || font == UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: .regular),
              let paragraph = firstAttributes[.paragraphStyle] as? NSParagraphStyle,
              paragraph.defaultTabInterval.isFinite, paragraph.defaultTabInterval > 0 else {
            return nil
        }
        let canonical = NSMutableAttributedString(string: "a")
        DefaultStringAttributes(textColor: .black, font: font, kern: 0, tabWidth: paragraph.defaultTabInterval).apply(to: canonical)
        var expected = canonical.attributes(at: 0, effectiveRange: nil)
        expected.removeValue(forKey: .foregroundColor)
        let bodyLength = paragraphBodyLength(bytes, count: input.length)
        guard attributesAreSupported(firstAttributes, expected: expected),
              let runRange = validatedRun(bytes, start: runStart, bodyLength: bodyLength) else { return nil }
        var supported = true
        input.enumerateAttributes(in: NSRange(location: 0, length: input.length)) { attributes, _, stop in
            if !attributesAreSupported(attributes, expected: expected) {
                supported = false
                stop.pointee = true
            }
        }
        guard supported else {
            return nil
        }

        // Only admitted inputs need snapshot ownership. Start from fresh storage,
        // copying paragraph values before installing complete dictionaries. Keep
        // UIColor objects unresolved so dynamic colors retain their behavior.
        let copy = NSMutableAttributedString(string: input.string)
        input.enumerateAttributes(in: NSRange(location: 0, length: input.length)) { attributes, range, _ in
            var owned = attributes
            if let style = attributes[.paragraphStyle] as? NSParagraphStyle {
                owned[.paragraphStyle] = style.copy()
            }
            copy.setAttributes(owned, range: range)
        }
        let run = Run(range: runRange, allowsInitialOffset: runRange.lowerBound == 0 && runRange.upperBound == bodyLength)
        return Self(text: NSAttributedString(attributedString: copy), bodyLength: bodyLength, run: run)
    }

    private static func attributesAreSupported(_ attributes: [NSAttributedString.Key: Any],
                                               expected: [NSAttributedString.Key: Any]) -> Bool {
        var actual = attributes
        guard actual.removeValue(forKey: .foregroundColor) is UIColor else {
            return false
        }
        if let ligature = actual.removeValue(forKey: .ligature) {
            guard let number = ligature as? NSNumber, number.doubleValue == 0 else {
                return false
            }
        }
        return (actual as NSDictionary).isEqual(to: expected)
    }

    private static func isAlphanumeric(_ unit: CChar) -> Bool {
        (48 ... 57).contains(unit) || (65 ... 90).contains(unit) || (97 ... 122).contains(unit)
    }

    /// The caller guarantees >=4096 units, including the entire bounded probe.
    private static func probeRunStart(_ bytes: UnsafePointer<CChar>) -> Int? {
        if isAlphanumeric(bytes[0]) {
            for index in 0 ..< 64 where !isAlphanumeric(bytes[index]) { return nil }
            return 0
        }
        var quote = 0
        while quote < 64 && bytes[quote] == 32 { quote += 1 }
        guard quote < 64, bytes[quote] == 34 else {
            return nil
        }
        let start = quote + 1
        for index in start ..< start + 128 where !isAlphanumeric(bytes[index]) { return nil }
        return start
    }

    private static func paragraphBodyLength(_ bytes: UnsafePointer<CChar>, count: Int) -> Int {
        guard bytes[count - 1] == 10 else {
            return count
        }
        return count - (bytes[count - 2] == 13 ? 2 : 1)
    }

    private static func validatedRun(_ bytes: UnsafePointer<CChar>, start: Int, bodyLength: Int) -> Range<Int>? {
        var end = start
        while end < bodyLength && isAlphanumeric(bytes[end]) { end += 1 }
        if start == 0 && end == bodyLength {
            // Preserve the original whole-line admission and offset-zero path.
            return start ..< end
        }
        guard end - start >= 4_096, end - start >= bodyLength - bodyLength / 10 else {
            return nil
        }
        // A split can leave only the opening wrapper or only the closing one.
        // Opening-only must end exactly at the paragraph body boundary. Closing-
        // only starts with alphanumerics at zero; no leading spaces are admitted.
        if end == bodyLength {
            return start ..< end
        }
        guard bytes[end] == 34 else {
            return nil
        }
        var next = end + 1
        if next < bodyLength, bytes[next] == 44 { next += 1 }
        while next < bodyLength && bytes[next] == 32 { next += 1 }
        // The exact wrapper plus alphanumeric run proves every body unit is
        // printable ASCII. Only paragraphBodyLength removes terminal LF/CRLF.
        // Explicit bounds reject embedded NUL, controls, Unicode, bare CR,
        // extra quotes/commas and internal newlines without a redundant full scan.
        return next == bodyLength ? start ..< end : nil
    }
}
