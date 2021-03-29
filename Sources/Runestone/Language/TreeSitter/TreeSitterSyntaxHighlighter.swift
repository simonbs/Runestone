//
//  TreeSitterSyntaxHighlighter.swift
//  
//
//  Created by Simon Støvring on 16/01/2021.
//

import UIKit

enum TreeSitterSyntaxHighlighterError: LocalizedError {
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

final class TreeSitterSyntaxHighlighter: LineSyntaxHighlighter {
    var theme: EditorTheme = DefaultEditorTheme()
    var canHighlight: Bool {
        return languageMode.canHighlight
    }

    private let languageMode: TreeSitterLanguageMode
    private let operationQueue: OperationQueue
    private var currentOperation: Operation?

    init(languageMode: TreeSitterLanguageMode, operationQueue: OperationQueue) {
        self.languageMode = languageMode
        self.operationQueue = operationQueue
    }

    func syntaxHighlight(_ input: LineSyntaxHighlighterInput) {
        let captures = languageMode.captures(in: input.byteRange)
        let tokens = self.tokens(for: captures, localTo: input.byteRange)
        setAttributes(for: tokens, on: input.attributedString)
    }

    func syntaxHighlight(_ input: LineSyntaxHighlighterInput, completion: @escaping AsyncCallback) {
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak operation, weak self] in
            guard let operation = operation, let self = self else {
                DispatchQueue.main.sync {
                    completion(.failure(TreeSitterSyntaxHighlighterError.operationDeallocated))
                }
                return
            }
            guard !operation.isCancelled else {
                DispatchQueue.main.sync {
                    completion(.failure(TreeSitterSyntaxHighlighterError.cancelled))
                }
                return
            }
            let captures = self.languageMode.captures(in: input.byteRange)
            if !operation.isCancelled {
                DispatchQueue.main.sync {
                    if !operation.isCancelled {
                        let tokens = self.tokens(for: captures, localTo: input.byteRange)
                        self.setAttributes(for: tokens, on: input.attributedString)
                        completion(.success(()))
                    } else {
                        completion(.failure(TreeSitterSyntaxHighlighterError.cancelled))
                    }
                }
            } else {
                DispatchQueue.main.sync {
                    completion(.failure(TreeSitterSyntaxHighlighterError.cancelled))
                }
            }
        }
        currentOperation = operation
        operationQueue.addOperation(operation)
    }

    func cancel() {
        currentOperation?.cancel()
        currentOperation = nil
    }
}

private extension TreeSitterSyntaxHighlighter {
    private func setAttributes(for tokens: [TreeSitterSyntaxHighlightToken], on attributedString: NSMutableAttributedString) {
        attributedString.beginEditing()
        let string = attributedString.string
        for token in tokens {
            let range = string.range(from: token.range)
            var attributes: [NSAttributedString.Key: Any] = [:]
            if let foregroundColor = token.textColor {
                attributes[.foregroundColor] = foregroundColor
            }
            if let font = token.font {
                attributes[.font] = font
            }
            if let shadow = token.shadow {
                attributes[.shadow] = shadow
            }
//            attributedString.removeAttribute(.foregroundColor, range: range)
//            attributedString.removeAttribute(.font, range: range)
//            attributedString.removeAttribute(.shadow, range: range)
            if !attributes.isEmpty {
                attributedString.addAttributes(attributes, range: range)
            }
        }
        attributedString.endEditing()
    }

    private func tokens(for captures: [TreeSitterCapture], localTo range: ByteRange) -> [TreeSitterSyntaxHighlightToken] {
        var tokens: [TreeSitterSyntaxHighlightToken] = []
        for capture in captures {
            // We highlight each line separately but a capture may extend beyond a line, e.g. an unterminated string,
            // so we need to cap the start and end location to ensure it's within the line.
            let cappedStartByte = max(capture.byteRange.location, range.location)
            let cappedEndByte = min(capture.byteRange.location + capture.byteRange.length, range.location + range.length)
            let length = cappedEndByte - cappedStartByte
            if length > ByteCount(0) {
                let cappedRange = ByteRange(location: cappedStartByte - range.location, length: length)
                let attrs = attributes(for: capture, in: cappedRange)
                if !attrs.isEmpty {
                    tokens.append(attrs)
                }
            }
        }
        return tokens
    }
}

private extension TreeSitterSyntaxHighlighter {
    private func attributes(for capture: TreeSitterCapture, in range: ByteRange) -> TreeSitterSyntaxHighlightToken {
        let textColor = theme.textColorForCaptureSequence(capture.name)
        let font = theme.fontForCaptureSequence(capture.name)
        let shadow = theme.shadowForCaptureSequence(capture.name)
        return TreeSitterSyntaxHighlightToken(range: range, textColor: textColor, font: font, shadow: shadow)
    }
}
