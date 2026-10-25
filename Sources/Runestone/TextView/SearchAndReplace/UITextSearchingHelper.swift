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

    // UIKit decorates results individually. Coalesce those updates so the highlight
    // service rebuilds its fragments once per batch instead of once per match.
    private var pendingDecorationRanges: [NSRange] = []
    private var pendingDecorations: [NSRange: HighlightedRange] = [:]
    private var pendingDecorationKeys: Set<NSRange> = []
    private var isDecorationUpdateScheduled = false
    private var pendingDecorationText: String?
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
        let range = foundTextRange.range
        if pendingDecorationKeys.isEmpty {
            pendingDecorationText = _textView.text
        }
        if pendingDecorationKeys.insert(range).inserted {
            pendingDecorationRanges.append(range)
        }
        pendingDecorations[range] = _textView.theme.highlightedRange(forFoundTextRange: range, ofStyle: style)
        if !isDecorationUpdateScheduled {
            isDecorationUpdateScheduled = true
            DispatchQueue.main.async { [weak self] in
                self?.applyPendingDecorations()
            }
        }
    }

    func clearAllDecoratedFoundText() {
        discardPendingDecorations()
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
        let range = foundTextRange.range
        let decoration = pendingDecorationKeys.contains(range)
            ? pendingDecorations[range]
            : _textView.highlightedRanges.first(where: { $0.range == range })
        guard let highlightedRange = decoration else {
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
    private func applyPendingDecorations() {
        isDecorationUpdateScheduled = false
        guard !pendingDecorationKeys.isEmpty,
              let textView = textView,
              let pendingDecorationText = pendingDecorationText,
              pendingDecorationText.utf16.elementsEqual(textView.text.utf16) else {
            discardPendingDecorations()
            return
        }
        var ranges = textView.highlightedRanges.filter { !pendingDecorationKeys.contains($0.range) }
        ranges.append(contentsOf: pendingDecorationRanges.compactMap { pendingDecorations[$0] })
        discardPendingDecorations()
        textView.highlightedRanges = ranges
    }

    private func discardPendingDecorations() {
        pendingDecorationRanges.removeAll(keepingCapacity: true)
        pendingDecorations.removeAll(keepingCapacity: true)
        pendingDecorationKeys.removeAll(keepingCapacity: true)
        pendingDecorationText = nil
    }

    private func addFindInteraction() {
        if #available(iOS 16, *), findInteraction == nil {
            let findInteraction = UIFindInteraction(sessionDelegate: self)
            self.findInteraction = findInteraction
            _textView.addInteraction(findInteraction)
        }
    }

    private func removeFindInteraction() {
        discardPendingDecorations()
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

@available(iOS 16, *)
extension UITextSearchingHelper: UIFindInteractionDelegate {
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
