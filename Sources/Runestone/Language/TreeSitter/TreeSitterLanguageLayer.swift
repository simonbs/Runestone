//
//  TreeSitterLanguageLayer.swift
//  
//
//  Created by Simon Støvring on 16/02/2021.
//

import Foundation

protocol TreeSitterLanguageLayerDelegate: AnyObject {
    func treeSitterLanguageLayer(_ languageLayer: TreeSitterLanguageLayer, bytesAt byteIndex: ByteCount) -> [Int8]?
}

final class TreeSitterLanguageLayer {
    weak var delegate: TreeSitterLanguageLayerDelegate?
    let capturedNode: TreeSitterNode?
    var rootNode: TreeSitterNode? {
        return parser.latestTree?.rootNode
    }
    var canHighlight: Bool {
        return parser.language != nil && parser.latestTree != nil
    }

    private let parser: TreeSitterParser
    private let highlightsQuery: TreeSitterQuery?
    private let injectionsQuery: TreeSitterQuery?
    private weak var injectedLanguageProvider: TreeSitterLanguageProvider?
    private var childLanguageLayers: [TreeSitterLanguageLayer] = []

    init(_ language: TreeSitterLanguage, capturedNode: TreeSitterNode?) {
        self.capturedNode = capturedNode
        highlightsQuery = language.highlightsQuery
        injectionsQuery = language.injectionsQuery
        injectedLanguageProvider = language.injectedLanguageProvider
        parser = TreeSitterParser(encoding: language.textEncoding.tsEncoding)
        parser.language = language.languagePointer
        parser.delegate = self
    }

    func parse(_ text: String) {
        parser.parse(text)
        childLanguageLayers.removeAll()
        if let injectionsQuery = injectionsQuery, let node = parser.latestTree?.rootNode {
            let injectionsQueryCursor = TreeSitterQueryCursor(query: injectionsQuery, node: node)
            injectionsQueryCursor.execute()
            let captures = injectionsQueryCursor.allCaptures()
            for capture in captures {
                if let childLanguageLayer = insertLanguageLayer(forInjectionCapture: capture) {
                    if let capturedNode = childLanguageLayer.capturedNode {
                        print(capturedNode.byteRange)
                        if let subtext = text.substring(with: capturedNode.byteRange) {
                            print(subtext)
                        }
                    }
                }
            }
        }
    }

    func apply(_ edit: TreeSitterInputEdit) -> LanguageModeTextChangeResult {
        let oldTree = parser.latestTree
        parser.apply(edit)
        parser.parse()
        if let oldTree = oldTree, let newTree = parser.latestTree {
            let changedRanges = oldTree.rangesChanged(comparingTo: newTree)
            var lineIndices: Set<Int> = []
            for changedRange in changedRanges {
                for lineIndex in changedRange.startPoint.row ... changedRange.endPoint.row {
                    lineIndices.insert(Int(lineIndex))
                }
            }
            let childResult = applyEditToChildren(edit)
            let allChangedLineIndices = lineIndices.union(childResult.changedLineIndices)
            return LanguageModeTextChangeResult(changedLineIndices: allChangedLineIndices)
        } else {
            return applyEditToChildren(edit)
        }
    }

    func captures(in range: ByteRange) -> [TreeSitterCapture] {
        guard let tree = parser.latestTree else {
            return []
        }
        guard let query = highlightsQuery else {
            return []
        }
        let captureQueryCursor = TreeSitterQueryCursor(query: query, node: tree.rootNode)
        captureQueryCursor.setQueryRange(range)
        captureQueryCursor.execute()
        return captureQueryCursor.allCaptures()
    }
}

private extension TreeSitterLanguageLayer {
    private func applyEditToChildren(_ edit: TreeSitterInputEdit) -> LanguageModeTextChangeResult {
        let changedLineIndices = Set(childLanguageLayers.flatMap { $0.apply(edit).changedLineIndices })
        return LanguageModeTextChangeResult(changedLineIndices: changedLineIndices)
    }

    @discardableResult
    private func insertLanguageLayer(forInjectionCapture capture: TreeSitterCapture) -> TreeSitterLanguageLayer? {
        guard let languageName = capture.properties["injection.language"] else {
            return nil
        }
        guard let language = injectedLanguageProvider?.treeSitterLanguage(named: languageName) else {
            return nil
        }
        let childLanguageLayer = TreeSitterLanguageLayer(language, capturedNode: capture.node)
        childLanguageLayer.delegate = self
        childLanguageLayers.append(childLanguageLayer)
        return childLanguageLayer
    }
}

extension TreeSitterLanguageLayer: TreeSitterParserDelegate {
    func parser(_ parser: TreeSitterParser, bytesAt byteIndex: ByteCount) -> [Int8]? {
        return delegate?.treeSitterLanguageLayer(self, bytesAt: byteIndex)
    }
}

extension TreeSitterLanguageLayer: TreeSitterLanguageLayerDelegate {
    func treeSitterLanguageLayer(_ languageLayer: TreeSitterLanguageLayer, bytesAt byteIndex: ByteCount) -> [Int8]? {
        return delegate?.treeSitterLanguageLayer(self, bytesAt: byteIndex)
    }
}
