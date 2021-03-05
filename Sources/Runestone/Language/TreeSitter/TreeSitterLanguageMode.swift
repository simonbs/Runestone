//
//  TreeSitterLanguageMode.swift
//  
//
//  Created by Simon Støvring on 05/12/2020.
//

import Foundation
import TreeSitter

protocol TreeSitterLanguageModeDelegate: AnyObject {
    func treeSitterLanguageMode(_ languageMode: TreeSitterLanguageMode, bytesAt byteIndex: ByteCount) -> [Int8]?
}

final class TreeSitterLanguageMode: LanguageMode {
    weak var delegate: TreeSitterLanguageModeDelegate?
    var canHighlight: Bool {
        return rootLanguageLayer.canHighlight
    }

    private let stringView: StringView
    private let parser: TreeSitterParser
    private let indentationScopes: TreeSitterIndentationScopes?
    private let rootLanguageLayer: TreeSitterLanguageLayer
    private let operationQueue = OperationQueue()

    init(language: TreeSitterLanguage, stringView: StringView) {
        self.stringView = stringView
        operationQueue.name = "TreeSitterLanguageMode"
        operationQueue.qualityOfService = .userInitiated
        parser = TreeSitterParser(encoding: language.textEncoding.treeSitterEncoding)
        indentationScopes = language.indentationScopes
        rootLanguageLayer = TreeSitterLanguageLayer(language: language, parser: parser, stringView: stringView)
        parser.delegate = self
    }

    func parse(_ text: String) {
        rootLanguageLayer.parse(text)
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
        return rootLanguageLayer.apply(edit)
    }

    func captures(in range: ByteRange) -> [TreeSitterCapture] {
        return rootLanguageLayer.captures(in: range)
    }
    
    func createLineSyntaxHighlighter() -> LineSyntaxHighlighter {
        return TreeSitterSyntaxHighlighter(languageMode: self, operationQueue: operationQueue)
    }

    func suggestedIndentLevel(for line: DocumentLineNode) -> Int {
        if let indentationScopes = indentationScopes {
            let indentController = TreeSitterIndentController(languageMode: self, indentationScopes: indentationScopes, stringView: stringView)
            return indentController.suggestedIndentLevel(for: line)
        } else {
            return 0
        }
    }

    func indentLevel(for line: DocumentLineNode) -> Int {
        var indentLength = 0
        let tabLength = 2
        let location = line.location
        for i in 0 ..< line.data.totalLength {
            let range = NSRange(location: location + i, length: 1)
            let str = stringView.substring(in: range).first
            if str == Symbol.Character.tab {
                indentLength += tabLength - (indentLength % tabLength)
            } else if str == Symbol.Character.space {
                indentLength += 1
            } else {
                break
            }
        }
        return indentLength / tabLength
    }

    func syntaxNode(at linePosition: LinePosition) -> SyntaxNode? {
        if let node = rootLanguageLayer.node(at: linePosition), let type = node.type {
            let startPosition = LinePosition(node.startPoint)
            let endPosition = LinePosition(node.endPoint)
            return SyntaxNode(type: type, startPosition: startPosition, endPosition: endPosition)
        } else {
            return nil
        }
    }

    func highestNode(at linePosition: LinePosition) -> TreeSitterNode? {
        guard var node = rootLanguageLayer.node(at: linePosition) else {
            return nil
        }
        while let parent = node.parent,
              parent.startPoint.row == node.startPoint.row
                && parent.endPoint.row == node.endPoint.row
                && parent.startPoint.column == node.startPoint.column {
            node = parent
        }
        return node
    }
}

extension TreeSitterLanguageMode: TreeSitterParserDelegate {
    func parser(_ parser: TreeSitterParser, bytesAt byteIndex: ByteCount) -> [Int8]? {
        return delegate?.treeSitterLanguageMode(self, bytesAt: byteIndex)
    }
}
