import Combine
import Foundation

final class SearchService<StringViewType: StringView, LineManagerType: LineManaging> {
    private let stringView: StringViewType
    private let textLocationConverter: TextLocationConverter<LineManagerType>

    init(stringView: StringViewType, textLocationConverter: TextLocationConverter<LineManagerType>) {
        self.stringView = stringView
        self.textLocationConverter = textLocationConverter
    }

    func search(for query: SearchQuery) -> [SearchResult] {
        search(for: query) { textCheckingResult in
            searchResult(in: textCheckingResult.range)
        }
    }

    func search(for query: SearchQuery, replacingMatchesWith replacementText: String) -> [SearchReplaceResult] {
        guard query.matchMethod == .regularExpression else {
            return search(for: query, replacingWithPlainText: replacementText)
        }
        let replacementStringParser = ReplacementStringParser(string: replacementText)
        let parsedReplacementString = replacementStringParser.parse()
        return search(for: query) { textCheckingResult in
            let replacementText = parsedReplacementString.string(
                byMatching: textCheckingResult,
                in: stringView.string as NSString
            )
            return searchReplaceResult(in: textCheckingResult.range, replacementText: replacementText)
        }
    }
}

private extension SearchService {
    private func search(for query: SearchQuery, replacingWithPlainText replacementText: String) -> [SearchReplaceResult] {
        search(for: query) { textCheckingResult in
            searchReplaceResult(in: textCheckingResult.range, replacementText: replacementText)
        }
    }

    private func search<T>(for query: SearchQuery, mappingResultsWith mapper: (NSTextCheckingResult) -> T?) -> [T] {
        guard !query.text.isEmpty else {
            return []
        }
        let matches = query.matches(in: stringView.string as NSString)
        return matches.compactMap { textCheckingResult in
            if textCheckingResult.range.length > 0, let mappedValue = mapper(textCheckingResult) {
                return mappedValue
            } else {
                return nil
            }
        }
    }

    private func searchResult(in range: NSRange) -> SearchResult? {
        guard let startTextLocation = textLocationConverter.textLocation(at: range.lowerBound) else {
            return nil
        }
        guard let endTextLocation = textLocationConverter.textLocation(at: range.upperBound) else {
            return nil
        }
        return SearchResult(range: range, startLocation: startTextLocation, endLocation: endTextLocation)
    }

    private func searchReplaceResult(in range: NSRange, replacementText: String) -> SearchReplaceResult? {
        guard let startTextLocation = textLocationConverter.textLocation(at: range.lowerBound) else {
            return nil
        }
        guard let endTextLocation = textLocationConverter.textLocation(at: range.upperBound) else {
            return nil
        }
        return SearchReplaceResult(
            range: range,
            startLocation: startTextLocation,
            endLocation: endTextLocation,
            replacementText: replacementText
        )
    }
}