import UIKit

final class UITextSearchingController {
    weak var textView: TextView?

    private var latestSearchQuery: SearchQuery?
    private let queue = OperationQueue()
    private var _textView: TextView {
        if let textView = textView {
            return textView
        } else {
            fatalError("Text view has been deallocated.")
        }
    }

    init() {
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
    }

    @available(iOS 16, *)
    func compare(_ foundRange: UITextRange, toRange: UITextRange, document: AnyHashable??) -> ComparisonResult {
        guard let foundRange = foundRange as? IndexedRange, let toRange = toRange as? IndexedRange else {
            fatalError("Expected indexed ranges.")
        }
        if foundRange.range.location < toRange.range.location {
            return .orderedAscending
        } else if foundRange.range.location > toRange.range.location {
            return .orderedDescending
        } else if foundRange.range.length < toRange.range.length {
            return .orderedAscending
        } else if foundRange.range.length > toRange.range.length {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }

    @available(iOS 16, *)
    func performTextSearch(queryString: String, options: UITextSearchOptions, resultAggregator: UITextSearchAggregator<AnyHashable?>) {
        queue.cancelAllOperations()
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let self = self, let operation = operation, !operation.isCancelled else {
                return
            }
            let query = SearchQuery(queryString: queryString, options: options)
            self.latestSearchQuery = query
            let results = self._textView.search(for: query)
            for result in results {
                let textRange = IndexedRange(result.range)
                resultAggregator.foundRange(textRange, searchString: queryString, document: nil)
            }
            resultAggregator.finishedSearching()
        }
        queue.addOperation(operation)
    }

    @available(iOS 16, *)
    func decorate(foundTextRange: UITextRange, document: AnyHashable??, usingStyle style: UITextSearchFoundTextStyle) {
        if let foundTextRange = foundTextRange as? IndexedRange {
            _textView.highlightedRanges.removeAll(where: { $0.range == foundTextRange.range })
            switch style {
            case .found:
                let highlightedRange = HighlightedRange(range: foundTextRange.range, color: .yellow.withAlphaComponent(0.2))
                _textView.highlightedRanges.append(highlightedRange)
            case .highlighted:
                let highlightedRange = HighlightedRange(range: foundTextRange.range, color: .yellow)
                _textView.highlightedRanges.append(highlightedRange)
            case .normal:
                break
            @unknown default:
                break
            }
        }
    }

    @available(iOS 16, *)
    func clearAllDecoratedFoundText() {
        _textView.highlightedRanges = []
    }

    @available(iOS 16, *)
    func replaceAll(queryString: String, options: UITextSearchOptions, withText replacementText: String) {
        let query = SearchQuery(queryString: queryString, options: options)
        let results = _textView.search(for: query, replacingMatchesWith: replacementText)
        let replacements = results.map { result in
            return BatchReplaceSet.Replacement(range: result.range, text: result.replacementText)
        }
        let batchReplaceSet = BatchReplaceSet(replacements: replacements)
        _textView.replaceText(in: batchReplaceSet)
    }

    @available(iOS 16, *)
    func replace(foundTextRange: UITextRange, document: AnyHashable??, withText replacementText: String) {
        if let foundTextRange = foundTextRange as? IndexedRange, let searchQuery = latestSearchQuery {
            let results = _textView.search(for: searchQuery, replacingMatchesWith: replacementText)
            let filteredResults = results.filter { $0.range == foundTextRange.range }
            let replacements = filteredResults.map { result in
                return BatchReplaceSet.Replacement(range: result.range, text: result.replacementText)
            }
            let batchReplaceSet = BatchReplaceSet(replacements: replacements)
            _textView.replaceText(in: batchReplaceSet)
        }
    }

    @available(iOS 16, *)
    func shouldReplace(foundTextRange: UITextRange, document: AnyHashable??, withText replacementText: String) -> Bool {
        return true
    }
}

private extension SearchQuery {
    @available(iOS 16, *)
    init(queryString: String, options: UITextSearchOptions) {
        let isRegularExpression = options.stringCompareOptions.contains(.regularExpression)
        let isCaseSensitive = !options.stringCompareOptions.contains(.caseInsensitive)
        self.init(text: queryString, isRegularExpression: isRegularExpression, isCaseSensitive: isCaseSensitive)
    }
}
