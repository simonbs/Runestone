#if canImport(AppKit)
import AppKit
import RunestoneEngine

/// Conservatively admits long printable-ASCII editor paragraphs to bounded
/// cluster measurement plus Runestone's word-boundary lookback.
struct AppKitLineTypesetterPreparation: LineTypesetterPreparation {
    private static let minimumLength = 4_096
    private static let allowedAttributeKeys: Set<NSAttributedString.Key> = [
        .font, .foregroundColor, .backgroundColor
    ]

    func prepare(_ input: NSAttributedString) -> PreparedLineTypesetterInput? {
        guard input.length >= Self.minimumLength,
              let string = CFAttributedStringGetString(input),
              let bytes = CFStringGetCStringPtr(string, CFStringBuiltInEncodings.ASCII.rawValue) else { return nil }
        let bodyLength = paragraphBodyLength(bytes, count: input.length)
        guard bodyLength >= Self.minimumLength, isSupportedASCII(bytes, bodyLength: bodyLength, totalLength: input.length),
              hasSupportedAttributes(input) else { return nil }
        let copy = NSAttributedString(attributedString: input)
        return PreparedLineTypesetterInput(
            text: copy,
            run: LineTypesetterRun(range: 0..<bodyLength, allowsInitialOffset: true, breakStrategy: .word)
        )
    }

    func reusablePrefixCount(from old: NSAttributedString, to new: NSAttributedString,
                             fragments: [LineFragment], limit: Int) -> Int { 0 }

    func stringForTypesetting(_ input: NSAttributedString) -> NSAttributedString {
        TokenBackgroundMapping.stringForTypesetting(input, backgroundColorKey: .backgroundColor)
    }

    private func paragraphBodyLength(_ bytes: UnsafePointer<CChar>, count: Int) -> Int {
        guard count > 0, bytes[count - 1] == 10 else { return count }
        return count > 1 && bytes[count - 2] == 13 ? count - 2 : count - 1
    }

    private func isSupportedASCII(_ bytes: UnsafePointer<CChar>, bodyLength: Int, totalLength: Int) -> Bool {
        for index in 0..<bodyLength where !(32...126).contains(Int(bytes[index])) { return false }
        guard bodyLength < totalLength else { return true }
        if totalLength - bodyLength == 1 { return bytes[bodyLength] == 10 }
        return totalLength - bodyLength == 2 && bytes[bodyLength] == 13 && bytes[bodyLength + 1] == 10
    }

    private func hasSupportedAttributes(_ input: NSAttributedString) -> Bool {
        var supported = true
        input.enumerateAttributes(in: NSRange(location: 0, length: input.length)) { attributes, _, stop in
            guard Set(attributes.keys).isSubset(of: Self.allowedAttributeKeys),
                  attributes[.font] is NSFont,
                  attributes[.foregroundColor] == nil || attributes[.foregroundColor] is NSColor,
                  attributes[.backgroundColor] == nil || attributes[.backgroundColor] is NSColor else {
                supported = false
                stop.pointee = true
                return
            }
        }
        return supported
    }
}
#endif
