//
//  SearchController.swift
//  
//
//  Created by Simon on 14/11/2021.
//

import Foundation

protocol SearchControllerDelegate: AnyObject {
    func searchController(_ searchController: SearchController, linePositionAt location: Int) -> LinePosition?
}

final class SearchController {
    weak var delegate: SearchControllerDelegate?

    private let stringView: StringView

    init(stringView: StringView) {
        self.stringView = stringView
    }

    func search(for query: SearchQuery) -> [SearchResult] {
        return search(for: query) { textCheckingResult in
            return searchResult(in: textCheckingResult.range)
        }
    }

    func search(for query: SearchQuery, replacingMatchesWith replacementText: String) -> [SearchReplaceResult] {
        guard query.isRegularExpression else {
            return search(for: query, replacingWithPlainText: replacementText)
        }
        let replacementStringParser = ReplacementStringParser(string: replacementText)
        let parsedReplacementString = replacementStringParser.parse()
        guard parsedReplacementString.containsPlaceholder else {
            return search(for: query, replacingWithPlainText: replacementText)
        }
        return search(for: query) { textCheckingResult in
            let replacementText = parsedReplacementString.string(byMatching: textCheckingResult, in: stringView.string)
            return searchReplaceResult(in: textCheckingResult.range, replacementText: replacementText)
        }
    }
}

private extension SearchController {
    private func search(for query: SearchQuery, replacingWithPlainText replacementText: String) -> [SearchReplaceResult] {
        return search(for: query) { textCheckingResult in
            return searchReplaceResult(in: textCheckingResult.range, replacementText: replacementText)
        }
    }

    private func search<T>(for query: SearchQuery, mappingResultsWith mapper: (NSTextCheckingResult) -> T?) -> [T] {
        guard !query.text.isEmpty else {
            return []
        }
        do {
            let regex = try query.makeRegularExpression()
            let range = NSRange(location: 0, length: stringView.string.length)
            let matches = regex.matches(in: stringView.string as String, options: [], range: range)
            var searchResults: [T] = []
            for match in matches where match.range.length > 0 {
                if let searchResult = mapper(match) {
                    searchResults.append(searchResult)
                }
            }
            return searchResults
        } catch {
            print(error)
            return []
        }
    }

    private func searchResult(in range: NSRange) -> SearchResult? {
        guard let startLinePosition = delegate?.searchController(self, linePositionAt: range.lowerBound) else {
            return nil
        }
        guard let endLinePosition = delegate?.searchController(self, linePositionAt: range.upperBound) else {
            return nil
        }
        return SearchResult(range: range, startLinePosition: startLinePosition, endLinePosition: endLinePosition)
    }

    private func searchReplaceResult(in range: NSRange, replacementText: String) -> SearchReplaceResult? {
        guard let startLinePosition = delegate?.searchController(self, linePositionAt: range.lowerBound) else {
            return nil
        }
        guard let endLinePosition = delegate?.searchController(self, linePositionAt: range.upperBound) else {
            return nil
        }
        return SearchReplaceResult(
            range: range,
            startLinePosition: startLinePosition,
            endLinePosition: endLinePosition,
            replacementText: replacementText)
    }
}
