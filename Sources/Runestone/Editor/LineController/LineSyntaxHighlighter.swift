//
//  LineSyntaxHighlighter.swift
//  
//
//  Created by Simon Støvring on 03/02/2021.
//

import Foundation

enum LineSyntaxHighlighterError: LocalizedError {
    case failedCreatingCaptures
    case cancelled
    case operationDeallocated

    var errorDescription: String? {
        switch self {
        case .failedCreatingCaptures:
            return "Failed creating captures"
        case .cancelled:
            return "Operation was cancelled"
        case .operationDeallocated:
            return "The operation was deallocated"
        }
    }
}

final class LineSyntaxHighlighter {
    typealias AsyncCallback = (Result<Void, LineSyntaxHighlighterError>) -> Void

    var theme: EditorTheme = DefaultEditorTheme()

    private let syntaxHighlighter: SyntaxHighlighter
    private let queue: OperationQueue
    private var currentOperation: Operation?

    init(syntaxHighlighter: SyntaxHighlighter, queue: OperationQueue) {
        self.syntaxHighlighter = syntaxHighlighter
        self.queue = queue
    }

    func setDefaultAttributes(on attributedString: NSMutableAttributedString) {
        let entireRange = NSRange(location: 0, length: attributedString.length)
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: theme.textColor,
            .font: theme.font
        ]
        attributedString.setAttributes(attributes, range: entireRange)
    }

    func syntaxHighlight(_ attributedString: NSMutableAttributedString, documentByteRange: ByteRange) {
        cancelHighlightOperation()
        if case let .success(captures) = syntaxHighlighter.captures(in: documentByteRange) {
            let tokens = syntaxHighlighter.tokens(for: captures, localTo: documentByteRange)
            setAttributes(for: tokens, on: attributedString)
        }
    }

    func syntaxHighlight(_ attributedString: NSMutableAttributedString, documentByteRange: ByteRange, completion: @escaping AsyncCallback) {
        cancelHighlightOperation()
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak operation, weak self] in
            guard let operation = operation, let self = self else {
                DispatchQueue.main.sync {
                    completion(.failure(.operationDeallocated))
                }
                return
            }
            guard !operation.isCancelled else {
                DispatchQueue.main.sync {
                    completion(.failure(.cancelled))
                }
                return
            }
            if case let .success(captures) = self.syntaxHighlighter.captures(in: documentByteRange) {
                if !operation.isCancelled {
                    DispatchQueue.main.sync {
                        if !operation.isCancelled {
                            let tokens = self.syntaxHighlighter.tokens(for: captures, localTo: documentByteRange)
                            self.setAttributes(for: tokens, on: attributedString)
                            completion(.success(()))
                        } else {
                            completion(.failure(.cancelled))
                        }
                    }
                } else {
                    DispatchQueue.main.sync {
                        completion(.failure(.cancelled))
                    }
                }
            } else {
                DispatchQueue.main.sync {
                    completion(.failure(.failedCreatingCaptures))
                }
            }
        }
        currentOperation = operation
        queue.addOperation(operation)
    }

    func cancelHighlightOperation() {
        currentOperation?.cancel()
        currentOperation = nil
    }
}

private extension LineSyntaxHighlighter {
    private func setAttributes(for tokens: [SyntaxHighlightToken], on attributedString: NSMutableAttributedString) {
        attributedString.beginEditing()
        let string = attributedString.string
        for token in tokens {
            let range = string.range(from: token.range)
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: token.textColor ?? theme.textColor,
                .font: token.font ?? theme.font
            ]
            attributedString.setAttributes(attributes, range: range)
        }
        attributedString.endEditing()
    }
}
