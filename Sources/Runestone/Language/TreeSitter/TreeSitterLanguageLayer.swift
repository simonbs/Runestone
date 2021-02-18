//
//  TreeSitterLanguageLayer.swift
//  
//
//  Created by Simon Støvring on 16/02/2021.
//

import Foundation

protocol TreeSitterLanguageLayerDelegate: AnyObject {
    func treeSitterLanguageLayer(_ languageLayer: TreeSitterLanguageLayer, linePositionAt byteOffset: ByteCount) -> LinePosition?
    func treeSitterLanguageLayer(_ languageLayer: TreeSitterLanguageLayer, bytesAt byteIndex: ByteCount) -> [Int8]?
}

final class TreeSitterLanguageLayer {
    weak var delegate: TreeSitterLanguageLayerDelegate?
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
    private let capturedNode: TreeSitterNode?

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
                        if let subtext = text.substring(with: capturedNode.byteRange) {
                            childLanguageLayer.parse(subtext)
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
        var lineIndices: Set<Int> = []
        if let oldTree = oldTree, let newTree = parser.latestTree {
            let changedRanges = oldTree.rangesChanged(comparingTo: newTree)
            for changedRange in changedRanges {
                for lineIndex in changedRange.startPoint.row ... changedRange.endPoint.row {
                    lineIndices.insert(Int(lineIndex))
                }
            }
        }
//        let injectionsQueryCursor = TreeSitterQueryCursor(query: injectionsQuery, node: node)
//        injectionsQueryCursor.execute()
//        let captures = injectionsQueryCursor.allCaptures()
//        for capture in captures {
//            if let childLanguageLayer = insertLanguageLayer(forInjectionCapture: capture) {
//                if let capturedNode = childLanguageLayer.capturedNode {
//                    if let subtext = text.substring(with: capturedNode.byteRange) {
//                        childLanguageLayer.parse(subtext)
//                    }
//                }
//            }
//        }

        applyEditToChildren(edit)
        return LanguageModeTextChangeResult(changedLineIndices: lineIndices)
    }

    func captures(in range: ByteRange) -> [TreeSitterCapture] {
        guard let tree = parser.latestTree else {
            return []
        }
        guard let query = highlightsQuery else {
            return []
        }
        let localRange = self.localRange(from: range)
        let childCaptures = capturesInChildren(in: localRange)
        let captureQueryCursor = TreeSitterQueryCursor(query: query, node: tree.rootNode)
        captureQueryCursor.setQueryRange(localRange)
        captureQueryCursor.execute()
        let captures = captureQueryCursor.allCaptures()
        return captures + childCaptures
    }

    private func localRange(from parentRange: ByteRange) -> ByteRange {
        if let capturedNode = capturedNode {
            let startByte = max(parentRange.location, capturedNode.startByte) - capturedNode.startByte
            let length = min(parentRange.length, capturedNode.byteRange.length)
            return ByteRange(location: startByte, length: length)
        } else {
            return parentRange
        }
    }
}

private extension TreeSitterLanguageLayer {
    private func applyEditToChildren(_ edit: TreeSitterInputEdit) {
        for childLanguageLayer in childLanguageLayers {
            if let parentNode = childLanguageLayer.capturedNode {
                let startByte = min(max(edit.startByte, parentNode.startByte), parentNode.endByte) - parentNode.startByte
                let oldEndByte = min(max(edit.oldEndByte, parentNode.startByte), parentNode.endByte) - parentNode.startByte
                let newEndByte = min(max(edit.newEndByte, parentNode.startByte), parentNode.endByte) - parentNode.startByte
                let startLinePosition = delegate!.treeSitterLanguageLayer(self, linePositionAt: startByte)!
                let oldEndLinePosition = delegate!.treeSitterLanguageLayer(self, linePositionAt: oldEndByte)!
                let newEndLinePosition = delegate!.treeSitterLanguageLayer(self, linePositionAt: newEndByte)!
                let childEdit = TreeSitterInputEdit(
                    startByte: startByte,
                    oldEndByte: oldEndByte,
                    newEndByte: newEndByte,
                    startPoint: TreeSitterTextPoint(startLinePosition),
                    oldEndPoint: TreeSitterTextPoint(oldEndLinePosition),
                    newEndPoint: TreeSitterTextPoint(newEndLinePosition))
                print(childEdit)
                _ = childLanguageLayer.apply(childEdit)
            }
        }
    }

    private func capturesInChildren(in range: ByteRange) -> [TreeSitterCapture] {
        var captures: [TreeSitterCapture] = []
        for childLanguageLayer in childLanguageLayers {
            if let parentNode = childLanguageLayer.capturedNode, range.overlaps(parentNode.byteRange) {
                let childCaptures = childLanguageLayer.captures(in: range).map { capture in
                    return capture.offsettingByteRange(by: parentNode.startByte)
                }
                captures.append(contentsOf: childCaptures)
            }
        }
        return captures
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

    func treeSitterLanguageLayer(_ languageLayer: TreeSitterLanguageLayer, linePositionAt byteOffset: ByteCount) -> LinePosition? {
        return delegate?.treeSitterLanguageLayer(self, linePositionAt: byteOffset)
    }
}
