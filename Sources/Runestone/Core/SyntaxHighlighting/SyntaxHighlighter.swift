import _RunestoneMultiPlatform
import Combine
import Foundation

private enum SyntaxHighlighterError: LocalizedError {
    case cancelled
    case operationDeallocated

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Operation was cancelled"
        case .operationDeallocated:
            return "The operation was deallocated"
        }
    }
}

protocol SyntaxHighlighter: AnyObject {
    typealias AsyncCallback = (Result<Void, Error>) -> Void
    associatedtype AsyncWorkResult
    var inlinePredictionRange: NSRange? { get set }
    var operationQueue: OperationQueue { get }
    func syntaxHighlight(_ input: SyntaxHighlighterInput)
    func syntaxHighlight(_ input: SyntaxHighlighterInput, completion: @escaping AsyncCallback)
    func performHeavyBackgroundSafeWork(with input: SyntaxHighlighterInput) -> AsyncWorkResult
    func performWorkRequiringMainQueue(with input: SyntaxHighlighterInput, using result: AsyncWorkResult)
    func cancel()
}

extension SyntaxHighlighter {
    func performHeavyBackgroundSafeWork(with input: SyntaxHighlighterInput) -> Void {}

    func performWorkRequiringMainQueue(with input: SyntaxHighlighterInput, using result: Void) {}

    func syntaxHighlight(_ input: SyntaxHighlighterInput) {
        let result = performHeavyBackgroundSafeWork(with: input)
        performWorkRequiringMainQueue(with: input, using: result)
    }

    func syntaxHighlight(_ input: SyntaxHighlighterInput, completion: @escaping AsyncCallback) {
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak operation, weak self] in
            guard let operation = operation, let self = self else {
                DispatchQueue.main.async {
                    completion(.failure(SyntaxHighlighterError.operationDeallocated))
                }
                return
            }
            guard !operation.isCancelled else {
                DispatchQueue.main.async {
                    completion(.failure(SyntaxHighlighterError.cancelled))
                }
                return
            }
            let result = self.performHeavyBackgroundSafeWork(with: input)
            DispatchQueue.main.async {
                if !operation.isCancelled {
                    self.performWorkRequiringMainQueue(with: input, using: result)
                    self.applyInlinePredictionStyle(to: input.attributedString)
                    completion(.success(()))
                } else {
                    completion(.failure(SyntaxHighlighterError.cancelled))
                }
            }
        }
        operationQueue.addOperation(operation)
    }

    func applyInlinePredictionStyle(to attributedString: NSMutableAttributedString) {
        guard let inlinePredictionRange else {
            return
        }
        var effectiveRange = NSRange(location: inlinePredictionRange.location, length: 0)
        while effectiveRange.upperBound < inlinePredictionRange.upperBound {
            if let foregroundColor = attributedString.foregroundColor(at: inlinePredictionRange.location, effectiveRange: &effectiveRange) {
                var alpha: CGFloat = 0
                foregroundColor.getRed(nil, green: nil, blue: nil, alpha: &alpha)
                let newForegroundColor = foregroundColor.withAlphaComponent(alpha / 2)
                let cappedRange = effectiveRange.capped(to: inlinePredictionRange)
                attributedString.addAttribute(.foregroundColor, value: newForegroundColor, range: cappedRange)
            }
        }
    }

    func cancel() {
        operationQueue.cancelAllOperations()
    }
}

private extension NSAttributedString {
    func foregroundColor(at location: Int, effectiveRange: inout NSRange) -> MultiPlatformColor? {
        attribute(.foregroundColor,at: location, effectiveRange: &effectiveRange) as? MultiPlatformColor
    }
}
