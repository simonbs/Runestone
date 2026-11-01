import Foundation
import NaturalLanguage

/// Called only on the language worker. Test detectors may return deterministic hypotheses.
protocol SpellingLanguageDetecting: AnyObject {
    func hypotheses(for text: String) -> [String: Double]
}

final class NaturalLanguageSpellingDetector: SpellingLanguageDetecting {
    func hypotheses(for text: String) -> [String: Double] {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 3)
        guard let dominant = hypotheses.max(by: { $0.value < $1.value })?.key else {
            return [:]
        }
        // Paragraph scores are not mixture proportions. Check a few complete, substantial sentences
        // independently so clearly bilingual paragraphs conservatively retain the fallback dictionaries.
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: [.bySentences]) { sentence, _, _, _ in
            if let sentence = sentence, ParagraphSpellingLanguageService.isProse(sentence) {
                sentences.append(sentence)
            }
        }
        let indices = Set([0, sentences.count / 2, sentences.count - 1]).filter { sentences.indices.contains($0) }.sorted()
        var disagreement = false
        for index in indices {
            recognizer.reset()
            recognizer.processString(sentences[index])
            let scores = recognizer.languageHypotheses(withMaximum: 2).sorted { $0.value > $1.value }
            if let first = scores.first, first.value >= 0.9,
               first.value - (scores.dropFirst().first?.value ?? 0) >= 0.2, first.key != dominant {
                disagreement = true
                break
            }
        }
        return disagreement ? [:] : Dictionary(uniqueKeysWithValues: hypotheses.map { ($0.key.rawValue, $0.value) })
    }
}
