import Foundation

/// Inference-only cleanup. Original document ranges and the host's spelling exclusions remain unchanged.
enum SpellingProseSample {
    private static let inlineCode = try? NSRegularExpression(pattern: #"(?<!`)(`{1,2})(?!`)[^\r\n]*?\1(?!`)"#)
    private static let url = try? NSRegularExpression(pattern: #"(?:https?://|www\.)[^\s<>]+"#)

    static func cleaned(_ text: String) -> String? {
        guard !text.contains("```") else {
            return nil
        }
        let withoutCode = removing(inlineCode, from: text)
        let prose = removing(url, from: withoutCode)
        guard !prose.contains("{"), !prose.contains("}"), !prose.contains("=>"), !prose.contains(" = ") else {
            return nil
        }
        return prose
    }

    private static func removing(_ expression: NSRegularExpression?, from text: String) -> String {
        expression?.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: text.utf16.count), withTemplate: " ") ?? text
    }
}
