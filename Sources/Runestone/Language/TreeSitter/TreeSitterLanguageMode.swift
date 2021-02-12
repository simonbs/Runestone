//
//  TreeSitterLanguageMode.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import Foundation
import TreeSitter
import RunestoneTreeSitter
import RunestoneUtils

final class TreeSitterLanguageMode: LanguageMode {
    weak var delegate: LanguageModeDelegate?

    private let language: UnsafePointer<TSLanguage>?
    private let highlightsQuery: TreeSitterHighlightsQuery?
    private let parser: Parser
    private let operationQueue = OperationQueue()
    private let syntaxHighlighter = TreeSitterSyntaxHighlighter()

    init(_ language: Language) {
        self.operationQueue.name = "TreeSitterLanguageMode"
        self.operationQueue.qualityOfService = .userInitiated
        self.language = language.languagePointer
        self.highlightsQuery = language.highlightsQuery
        parser = Parser(encoding: language.encoding)
        parser.language = language.languagePointer
        parser.delegate = self
    }

    func parse(_ text: String) {
        parser.parse(text)
        syntaxHighlighter.reset()
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

    func textDidChange(_ change: LanguageModeTextChange) {
        let bytesRemoved = change.byteRange.length
        let bytesAdded = change.newString.byteCount
        let edit = InputEdit(
            startByte: change.byteRange.location,
            oldEndByte: change.byteRange.location + bytesRemoved,
            newEndByte: change.byteRange.location + bytesAdded,
            startPoint: TextPoint(change.startLinePosition),
            oldEndPoint: TextPoint(change.oldEndLinePosition),
            newEndPoint: TextPoint(change.newEndLinePosition))
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
            delegate?.languageMode(self, didChangeLineIndices: lineIndices)
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

    func tokens(in range: ByteRange) -> [SyntaxHighlightToken] {
        return []
    }
}

extension TreeSitterLanguageMode: ParserDelegate {
    func parser(_ parser: Parser, bytesAt byteIndex: ByteCount) -> [Int8]? {
        return delegate?.languageMode(self, bytesAt: byteIndex)
    }
}
