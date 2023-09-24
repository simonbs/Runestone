import UIKit

final class UITextSearchingHelper: NSObject {
    weak var textView: TextView?
    var isFindInteractionEnabled = false {
        didSet {
            if isFindInteractionEnabled != oldValue {
                if isFindInteractionEnabled {
                    addFindInteraction()
                } else {
                    removeFindInteraction()
                }
            }
        }
    }
    @available(iOS 16, *)
    var findInteraction: UIFindInteraction? {
        get {
            guard let _findInteraction = _findInteraction else {
                return nil
            }
            guard let findInteraction = _findInteraction as? UIFindInteraction else {
                fatalError("Expected _findInteraction to be of type \(UIFindInteraction.self)")
            }
            return findInteraction
        }
        set {
            _findInteraction = newValue
        }
    }
    private var _findInteraction: Any?

    private let queue = OperationQueue()
    private var _textView: TextView {
        if let textView = textView {
            return textView
        } else {
            fatalError("Text view has been deallocated.")
        }
    }

    override init() {
        super.init()
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@available(iOS 16, *)
extension UITextSearchingHelper: UITextSearching {
    var supportsTextReplacement: Bool {
        true
    }

    var selectedTextRange: UITextRange? {
        _textView.selectedTextRange
    }

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

    func performTextSearch(queryString: String, options: UITextSearchOptions, resultAggregator: UITextSearchAggregator<AnyHashable?>) {
        performTextSearch(for: queryString, options: options) { searchResults in
            for searchResult in searchResults {
                let textRange = IndexedRange(searchResult.range)
                resultAggregator.foundRange(textRange, searchString: queryString, document: nil)
            }
            resultAggregator.finishedSearching()
        }
    }

    func decorate(foundTextRange: UITextRange, document: AnyHashable??, usingStyle style: UITextSearchFoundTextStyle) {
        guard let foundTextRange = foundTextRange as? IndexedRange else {
            return
        }
        _textView.highlightedRanges.removeAll { $0.range == foundTextRange.range }
        if let highlightedRange = _textView.theme.highlightedRange(forFoundTextRange: foundTextRange.range, ofStyle: style) {
            _textView.highlightedRanges.append(highlightedRange)
        }
    }

    func clearAllDecoratedFoundText() {
        _textView.highlightedRanges = []
    }

    func replaceAll(queryString: String, options: UITextSearchOptions, withText replacementText: String) {
        performTextSearch(for: queryString, options: options) { searchResults in
            let replacements = searchResults.map { BatchReplaceSet.Replacement(range: $0.range, text: replacementText) }
            let batchReplaceSet = BatchReplaceSet(replacements: replacements)
            DispatchQueue.main.sync {
                self._textView.replaceText(in: batchReplaceSet)
            }
        }
    }

    func replace(foundTextRange: UITextRange, document: AnyHashable??, withText replacementText: String) {
        _textView.replace(foundTextRange, withText: replacementText)
    }

    func shouldReplace(foundTextRange: UITextRange, document: AnyHashable??, withText replacementText: String) -> Bool {
        guard let foundTextRange = foundTextRange as? IndexedRange else {
            // iOS 16 beta 2 will call this function when presenting the find/replace navigator and pass <uninitialized> to foundTextRange. If we return false in this case, the find/replace UI will not be shown, so we need to return true when we can't convert the UITextRange to an IndexedRange.
            return true
        }
        guard let highlightedRange = _textView.highlightedRanges.first(where: { $0.range == foundTextRange.range }) else {
            return false
        }
        return _textView.editorDelegate?.textView(_textView, canReplaceTextIn: highlightedRange) ?? false
    }

    func scrollRangeToVisible(_ range: UITextRange, inDocument: AnyHashable??) {
        if let indexedRange = range as? IndexedRange {
            _textView.scrollRangeToVisible(indexedRange.range)
        }
    }
}

private extension UITextSearchingHelper {
    private func addFindInteraction() {
        if #available(iOS 16, *), findInteraction == nil {
            let findInteraction = UIFindInteraction(sessionDelegate: self)
            self.findInteraction = findInteraction
            _textView.addInteraction(findInteraction)
        }
    }

    private func removeFindInteraction() {
        if #available(iOS 16, *), let findInteraction = findInteraction {
            self.findInteraction = nil
            _textView.removeInteraction(findInteraction)
        }
    }

    @available(iOS 16.0, *)
    private func performTextSearch(for queryString: String, options: UITextSearchOptions, completion: @escaping ([SearchResult]) -> Void) {
        queue.cancelAllOperations()
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let self = self, let operation = operation, !operation.isCancelled else {
                return
            }
            let query = SearchQuery(queryString: queryString, options: options)
            let searchResults = self._textView.search(for: query)
            completion(searchResults)
        }
        queue.addOperation(operation)
    }
}

extension UITextSearchingHelper: UIFindInteractionDelegate {
    @available(iOS 16, *)
    func findInteraction(_ interaction: UIFindInteraction, sessionFor view: UIView) -> UIFindSession? {
        UITextSearchingFindSession(searchableObject: self)
    }
}

private extension SearchQuery {
    @available(iOS 16, *)
    init(queryString: String, options: UITextSearchOptions) {
        let matchMethod = SearchQuery.MatchMethod(options.wordMatchMethod)
        let isCaseSensitive = !options.stringCompareOptions.contains(.caseInsensitive)
        self.init(text: queryString, matchMethod: matchMethod, isCaseSensitive: isCaseSensitive)
    }
}

@available(iOS 16, *)
private extension SearchQuery.MatchMethod {
    init(_ matchMethod: UITextSearchOptions.WordMatchMethod) {
        switch matchMethod {
        case .contains:
            self = .contains
        case .startsWith:
            self = .startsWith
        case .fullWord:
            self = .fullWord
        @unknown default:
            self = .contains
        }
    }
}
