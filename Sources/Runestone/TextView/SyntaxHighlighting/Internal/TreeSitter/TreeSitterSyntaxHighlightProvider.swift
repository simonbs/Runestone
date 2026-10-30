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
    private var currentResources: TreeSitterHighlightRequest?

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
        let resources = TreeSitterHighlightRequest(snapshot: languageMode.makeHighlightSnapshot())
        let operation = BlockOperation()
        let request = TreeSitterSyntaxHighlightRequest(completion: completion)
        operation.addExecutionBlock { [weak operation, weak resources] in
            guard let operation, let resources, !operation.isCancelled,
                  let snapshot = resources.takeSnapshot() else { return }
            let captures = snapshot.captures(in: byteRange) { operation.isCancelled }
            if !operation.isCancelled {
                resources.complete(snapshot: snapshot, captures: captures)
            }
        }
        operation.completionBlock = { [weak self, weak operation, weak resources] in
            if operation?.isCancelled != false { resources?.cancel() }
            DispatchQueue.main.async { [weak self, weak operation, weak resources] in
                guard let self, let operation else {
                    request.complete(.failure(TreeSitterSyntaxHighlightProviderError.operationDeallocated))
                    return
                }
                defer {
                    if self.currentRequest === request {
                        self.currentRequest = nil
                        self.currentOperation = nil
                        self.currentResources = nil
                    }
                    resources?.cancel()
                }
                guard self.currentOperation === operation, self.isActive(request),
                      let completed = resources?.takeCompleted() else {
                    request.complete(.failure(TreeSitterSyntaxHighlightProviderError.cancelled))
                    return
                }
                withExtendedLifetime(completed.snapshot) {
                    let captures = completed.captures.map(TreeSitterSyntaxCapture.init)
                    let highlights = TreeSitterSyntaxHighlightMapper.highlights(for: captures, localTo: byteRange)
                    request.complete(.success(highlights))
                }
            }
        }
        currentRequest = request
        currentOperation = operation
        currentResources = resources
        operationQueue.addOperation(operation)
    }

    deinit {
        cancel()
    }

    func isActive(_ request: TreeSitterSyntaxHighlightRequest) -> Bool {
        currentRequest === request && currentOperation?.isCancelled == false
    }

    func cancel() {
        currentOperation?.cancel()
        currentResources?.cancel()
        currentResources = nil
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
