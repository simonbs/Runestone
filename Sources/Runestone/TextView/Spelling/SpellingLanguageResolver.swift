import Foundation

/// UIKit exposes only the primary language of a combined keyboard. Preferred system languages
/// supply additional dictionaries, while active input modes cover separately installed keyboards.
enum SpellingLanguageResolver {
    static func resolve(explicitLanguage: String?, keyboardLanguages: [String], preferredLanguages: [String],
                        availableLanguages: [String]) -> [String] {
        func match(_ preferred: String, allowsLanguageFallback: Bool) -> String? {
            let normalized = normalize(preferred)
            if let exact = availableLanguages.first(where: { normalize($0) == normalized }) {
                return exact
            }
            guard allowsLanguageFallback, let base = normalized.split(separator: "_").first else {
                return nil
            }
            return availableLanguages.first { normalize($0).split(separator: "_").first == base }
        }
        if let explicitLanguage {
            // A bare language leaves the dialect unspecified. Resolve it in Apple's preference order,
            // but never substitute another dialect or script for an explicitly qualified override.
            let isBareLanguage = !normalize(explicitLanguage).contains("_")
            return match(explicitLanguage, allowsLanguageFallback: isBareLanguage).map { [$0] } ?? []
        }
        var result: [String] = []
        for preferred in keyboardLanguages + preferredLanguages {
            if let language = match(preferred, allowsLanguageFallback: true), !result.contains(language) {
                result.append(language)
            }
        }
        return result.isEmpty ? availableLanguages.first.map { [$0] } ?? [] : result
    }

    private static func normalize(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "-", with: "_").lowercased()
    }
}
