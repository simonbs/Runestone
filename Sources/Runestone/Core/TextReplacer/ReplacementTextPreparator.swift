import Combine

struct ReplacementTextPreparator {
    private let lineEndings: CurrentValueSubject<LineEnding, Never>

    init(lineEndings: CurrentValueSubject<LineEnding, Never>) {
        self.lineEndings = lineEndings
    }

    func prepareText(_ text: String) -> String {
        // Ensure all line endings match our preferred line endings.
        let lineEndingsToReplace = LineEnding.allCases.filter { $0 != lineEndings.value }
        return lineEndingsToReplace.reduce(into: text) { text, lineEndingToReplace in
            text = text.replacingOccurrences(of: lineEndingToReplace.symbol, with: lineEndings.value.symbol)
        }
    }
}
