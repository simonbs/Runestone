import Foundation

/// UIKit exposes only the primary language of a combined keyboard. Preferred system languages
/// supply additional dictionaries, while active input modes cover separately installed keyboards.
enum SpellingLanguageResolver {
    static func resolve(explicitLanguage: String?, keyboardLanguages: [String], preferredLanguages: [String],
                        availableLanguages: [String]) -> [String] {
        func match(_ preferred: String, allowsLanguageFallback: Bool) -> String? {
            let normalized = preferred.replacingOccurrences(of: "-", with: "_")
            if let exact = availableLanguages.first(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) {
                return exact
            }
            guard allowsLanguageFallback, let base = normalized.split(separator: "_").first else {
                return nil
            }
            return availableLanguages.first { $0.split(separator: "_").first?.lowercased() == base.lowercased() }
        }
        if let explicitLanguage {
            return match(explicitLanguage, allowsLanguageFallback: false).map { [$0] } ?? []
        }
        var result: [String] = []
        for preferred in keyboardLanguages + preferredLanguages {
            if let language = match(preferred, allowsLanguageFallback: true), !result.contains(language) {
                result.append(language)
            }
        }
        return result.isEmpty ? availableLanguages.first.map { [$0] } ?? [] : result
    }
}
