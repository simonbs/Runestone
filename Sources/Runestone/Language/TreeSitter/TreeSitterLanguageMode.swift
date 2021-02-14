//
//  TreeSitterLanguageMode.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import Foundation
import TreeSitter

final class TreeSitterLanguageMode: LanguageMode {
    weak var delegate: LanguageModeDelegate?

    private let highlightsQuery: TreeSitterQuery?
    private let parser: TreeSitterParser
    private let operationQueue = OperationQueue()

    init(_ language: TreeSitterLanguage) {
        operationQueue.name = "TreeSitterLanguageMode"
        operationQueue.qualityOfService = .userInitiated
        highlightsQuery = Self.createHighlightsQuery(from: language)
        parser = TreeSitterParser(encoding: language.textEncoding.tsEncoding)
        parser.language = language.languagePointer
        parser.delegate = self
    }

    func parse(_ text: String) {
        parser.parse(text)
    }

    func parse(_ text: String, completion: @escaping ((Bool) -> Void)) {
        operationQueue.cancelAllOperations()
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak operation, weak self] in
            if let self = self, let operation = operation, !operation.isCancelled {
                self.parse(text)
                DispatchQueue.main.sync {
                    completion(!operation.isCancelled)
                }
            } else {
                DispatchQueue.main.sync {
                    completion(false)
                }
            }
        }
        operationQueue.addOperation(operation)
    }

    func textDidChange(_ change: LanguageModeTextChange) -> LanguageModeTextChangeResult {
        let bytesRemoved = change.byteRange.length
        let bytesAdded = change.newString.byteCount
        let edit = TreeSitterInputEdit(
            startByte: change.byteRange.location,
            oldEndByte: change.byteRange.location + bytesRemoved,
            newEndByte: change.byteRange.location + bytesAdded,
            startPoint: TreeSitterTextPoint(change.startLinePosition),
            oldEndPoint: TreeSitterTextPoint(change.oldEndLinePosition),
            newEndPoint: TreeSitterTextPoint(change.newEndLinePosition))
        let oldTree = parser.latestTree
        parser.apply(edit)
        parser.parse()
        // Find lines changed by Tree-sitter and tell delegate to rehighlight them
        if let oldTree = oldTree, let newTree = parser.latestTree {
            let changedRanges = oldTree.rangesChanged(comparingTo: newTree)
            var lineIndices: Set<Int> = []
            for changedRange in changedRanges {
                for lineIndex in changedRange.startPoint.row ... changedRange.endPoint.row {
                    lineIndices.insert(Int(lineIndex))
                }
            }
            return LanguageModeTextChangeResult(changedLineIndices: lineIndices)
        } else {
            return LanguageModeTextChangeResult(changedLineIndices: [])
        }
    }

    func tokenType(at location: Int) -> String? {
        if let byteOffset = delegate?.languageMode(self, byteOffsetAt: location) {
            let rootNode = parser.latestTree?.rootNode
            let byteRange = ByteRange(location: byteOffset, length: ByteCount(0))
            let node = rootNode?.namedDescendant(in: byteRange)
            return node?.type
        } else {
            return nil
        }
    }

    func createLineSyntaxHighlighter() -> LineSyntaxHighlighter {
        return TreeSitterSyntaxHighlighter(parser: parser, highlightsQuery: highlightsQuery, queue: operationQueue)
    }
}

private extension TreeSitterLanguageMode {
    private static func createHighlightsQuery(from language: TreeSitterLanguage) -> TreeSitterQuery? {
        language.highlightsQuery?.prepare()
        guard let queryString = language.highlightsQuery?.string else {
            return nil
        }
        let createQueryResult = TreeSitterQuery.create(fromSource: queryString, in: language.languagePointer)
        switch createQueryResult {
        case .success(let query):
            return query
        case .failure:
            return nil
        }
    }
}

extension TreeSitterLanguageMode: TreeSitterParserDelegate {
    func parser(_ parser: TreeSitterParser, bytesAt byteIndex: ByteCount) -> [Int8]? {
        return delegate?.languageMode(self, bytesAt: byteIndex)
    }
}
