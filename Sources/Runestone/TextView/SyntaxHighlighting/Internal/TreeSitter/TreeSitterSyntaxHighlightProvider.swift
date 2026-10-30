import Foundation

enum TreeSitterSyntaxHighlightProviderError: LocalizedError {
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

final class TreeSitterSyntaxHighlightRequest {
    private let lock = NSLock()
    private var didComplete = false
    private let completion: TreeSitterSyntaxHighlightProvider.AsyncCompletion

    fileprivate init(completion: @escaping TreeSitterSyntaxHighlightProvider.AsyncCompletion) {
        self.completion = completion
    }

    fileprivate func complete(_ result: Result<[SyntaxHighlight], Error>) {
        lock.lock()
        guard !didComplete else {
            lock.unlock()
            return
        }
        didComplete = true
        lock.unlock()
        completion(result, self)
    }
}

/// Produces semantic Tree-sitter highlights without resolving platform display styles.
final class TreeSitterSyntaxHighlightProvider {
    typealias AsyncCompletion = (Result<[SyntaxHighlight], Error>, TreeSitterSyntaxHighlightRequest) -> Void

    var canHighlight: Bool {
        languageMode.canHighlight
    }

    private let languageMode: TreeSitterInternalLanguageMode
    private let operationQueue: OperationQueue
    private var currentRequest: TreeSitterSyntaxHighlightRequest?
    private var currentOperation: BlockOperation?

    init(languageMode: TreeSitterInternalLanguageMode, operationQueue: OperationQueue) {
        self.languageMode = languageMode
        self.operationQueue = operationQueue
    }

    func highlights(in byteRange: ByteRange) -> [SyntaxHighlight] {
        cancel()
        let captures = languageMode.captures(in: byteRange).map(TreeSitterSyntaxCapture.init)
        return TreeSitterSyntaxHighlightMapper.highlights(for: captures, localTo: byteRange)
    }

    func highlights(in byteRange: ByteRange, completion: @escaping AsyncCompletion) {
        cancel()
        let snapshot = languageMode.makeHighlightSnapshot()
        let operation = BlockOperation()
        let request = TreeSitterSyntaxHighlightRequest(completion: completion)
        operation.addExecutionBlock { [weak operation, weak self] in
            guard let operation, let self else {
                DispatchQueue.main.async {
                    request.complete(.failure(TreeSitterSyntaxHighlightProviderError.operationDeallocated))
                }
                return
            }
            guard !operation.isCancelled else {
                self.finishOnMain(.failure(TreeSitterSyntaxHighlightProviderError.cancelled), request: request,
                                  keepingAlive: snapshot)
                return
            }
            let captures = snapshot.captures(in: byteRange) { operation.isCancelled }
                .map(TreeSitterSyntaxCapture.init)
            guard !operation.isCancelled else {
                self.finishOnMain(.failure(TreeSitterSyntaxHighlightProviderError.cancelled), request: request,
                                  keepingAlive: snapshot)
                return
            }
            let highlights = TreeSitterSyntaxHighlightMapper.highlights(for: captures, localTo: byteRange)
            self.finishOnMain(.success(highlights), request: request, keepingAlive: snapshot)
        }
        currentRequest = request
        currentOperation = operation
        operationQueue.addOperation(operation)
    }

    func isActive(_ request: TreeSitterSyntaxHighlightRequest) -> Bool {
        currentRequest === request && currentOperation?.isCancelled == false
    }

    func cancel() {
        currentOperation?.cancel()
        let cancelledRequest = currentRequest
        currentOperation = nil
        currentRequest = nil
        if let cancelledRequest {
            DispatchQueue.main.async {
                cancelledRequest.complete(.failure(TreeSitterSyntaxHighlightProviderError.cancelled))
            }
        }
    }
}

private extension TreeSitterSyntaxHighlightProvider {
    func finishOnMain(_ result: Result<[SyntaxHighlight], Error>,
                      request: TreeSitterSyntaxHighlightRequest,
                      keepingAlive snapshot: TreeSitterHighlightSnapshot) {
        DispatchQueue.main.async {
            defer {
                if self.currentRequest === request {
                    self.currentRequest = nil
                    self.currentOperation = nil
                }
            }
            withExtendedLifetime(snapshot) {
                request.complete(self.isActive(request) ? result : .failure(TreeSitterSyntaxHighlightProviderError.cancelled))
            }
        }
    }
}
