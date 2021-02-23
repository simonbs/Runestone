//
//  TreeSitterLanguageLayer.swift
//  
//
//  Created by Simon Støvring on 16/02/2021.
//

import Foundation

final class TreeSitterLanguageLayer {
    var rootNode: TreeSitterNode? {
        return tree?.rootNode
    }
    var canHighlight: Bool {
        return parser.language != nil && tree != nil
    }

    private let language: TreeSitterLanguage
    private let parser: TreeSitterParser
    private var childLanguageLayers: [TreeSitterLanguageLayer] = []
    private var tree: TreeSitterTree?
    private var isEmpty: Bool {
        if let rootNode = rootNode {
            return rootNode.endByte - rootNode.startByte <= ByteCount(0)
        } else {
            return true
        }
    }

    init(language: TreeSitterLanguage, parser: TreeSitterParser) {
        self.language = language
        self.parser = parser
    }

    func parse(_ text: String) {
        prepareParserToParse(from: rootNode)
        parseAndUpdateChildLayers(text: text)
    }

    func apply(_ edit: TreeSitterInputEdit) -> LanguageModeTextChangeResult {
        // Apply edit to tree.
        let oldTree = tree
        tree?.apply(edit)
        prepareParserToParse(from: rootNode)
        tree = parser.parse(oldTree: tree)
        // Apply edit to injected languages.
        var lineIndices = applyEditToChildren(edit)
        // Gather changed line indices.
        if let oldTree = oldTree, let newTree = tree {
            let changedRanges = oldTree.rangesChanged(comparingTo: newTree)
            for changedRange in changedRanges {
                for lineIndex in changedRange.startPoint.row ... changedRange.endPoint.row {
                    lineIndices.insert(Int(lineIndex))
                }
            }
        }
        updateChildLayers()
        return LanguageModeTextChangeResult(changedLineIndices: lineIndices)
    }

    func captures(in range: ByteRange) -> [TreeSitterCapture] {
        guard let tree = tree else {
            return []
        }
        guard let query = language.highlightsQuery else {
            return []
        }
        let childCaptures = capturesInChildren(in: range)
        let captureQueryCursor = TreeSitterQueryCursor(query: query, node: tree.rootNode)
        captureQueryCursor.setQueryRange(range)
        captureQueryCursor.execute()
        let captures = captureQueryCursor.allCaptures()
        let allCaptures = (captures + childCaptures).sorted(by: TreeSitterCapture.locationAndLengthSorting)
        // We ignore all captures with a predicate. We should handle these at some point.
        let filteredCaptures = allCaptures.filter { capture in
            return capture.predicates.isEmpty
        }
        return filteredCaptures
    }
}

private extension TreeSitterLanguageLayer {
    private func prepareParserToParse(from rootNode: TreeSitterNode?) {
        parser.language = language.languagePointer
        if let node = rootNode {
            let range = TreeSitterTextRange(startPoint: node.startPoint, endPoint: node.endPoint, startByte: node.startByte, endByte: node.endByte)
            parser.setIncludedRanges([range])
        } else {
            parser.removeAllIncludedRanges()
        }
    }

    private func parseAndUpdateChildLayers(text: String) {
        tree = parser.parse(text)
        childLanguageLayers.removeAll()
        if let injectionsQuery = language.injectionsQuery, let node = tree?.rootNode {
            let injectionsQueryCursor = TreeSitterQueryCursor(query: injectionsQuery, node: node)
            injectionsQueryCursor.execute()
            let captures = injectionsQueryCursor.allCaptures()
            for capture in captures {
                if let childLanguageLayer = insertLanguageLayer(forInjectionCapture: capture) {
                    childLanguageLayer.prepareParserToParse(from: capture.node)
                    childLanguageLayer.parseAndUpdateChildLayers(text: text)
                }
            }
        }
    }

    private func updateChildLayers() {
        guard let injectionsQuery = language.injectionsQuery, let node = tree?.rootNode else {
            childLanguageLayers.removeAll()
            return
        }
        let injectionsQueryCursor = TreeSitterQueryCursor(query: injectionsQuery, node: node)
        injectionsQueryCursor.execute()
        let captures = injectionsQueryCursor.allCaptures()
        let injectionByteRanges = captures.map(\.byteRange)
        // Remove language layers for ranges that no longer contain an injected language.
        childLanguageLayers.removeAll(where: { childLanguageLayer in
            if let rootNode = childLanguageLayer.rootNode {
                return !injectionByteRanges.contains(rootNode.byteRange)
            } else {
                return true
            }
        })
        // Insert language layers for new captures.
        for capture in captures {
            let childExists = childLanguageLayers.contains(where: { $0.rootNode?.byteRange == capture.node.byteRange })
            if !childExists, let childLanguageLayer = insertLanguageLayer(forInjectionCapture: capture) {
                childLanguageLayer.prepareParserToParse(from: capture.node)
                childLanguageLayer.tree = parser.parse(oldTree: nil)
            }
        }
        // Avoid having multiple layers span the same byte range.
        var seenByteRanges: Set<ByteRange> = []
        var resultingChildLanguageLayers: [TreeSitterLanguageLayer] = []
        for childLanguageLayer in childLanguageLayers {
            if let rootNode = childLanguageLayer.rootNode {
                if !seenByteRanges.contains(rootNode.byteRange) {
                    seenByteRanges.insert(rootNode.byteRange)
                    resultingChildLanguageLayers.append(childLanguageLayer)
                }
            }
        }
        childLanguageLayers = resultingChildLanguageLayers
    }

    private func applyEditToChildren(_ edit: TreeSitterInputEdit) -> Set<Int> {
        var lineIndices: Set<Int> = []
        for childLanguageLayer in childLanguageLayers {
            let childResult = childLanguageLayer.apply(edit)
            lineIndices.formUnion(childResult.changedLineIndices)
        }
        return lineIndices
    }

    private func capturesInChildren(in range: ByteRange) -> [TreeSitterCapture] {
        var captures: [TreeSitterCapture] = []
        for childLanguageLayer in childLanguageLayers {
            let childCaptures = childLanguageLayer.captures(in: range)
            captures.append(contentsOf: childCaptures)
        }
        return captures
    }

    @discardableResult
    private func insertLanguageLayer(forInjectionCapture capture: TreeSitterCapture) -> TreeSitterLanguageLayer? {
        guard let languageName = capture.properties["injection.language"] else {
            return nil
        }
        guard let language = language.injectedLanguageProvider?.treeSitterLanguage(named: languageName) else {
            return nil
        }
        let childLanguageLayer = TreeSitterLanguageLayer(language: language, parser: parser)
        childLanguageLayers.append(childLanguageLayer)
        return childLanguageLayer
    }
}

extension TreeSitterLanguageLayer: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[TreeSitterLanguageLayer node=\(rootNode?.debugDescription ?? "") childLanguageLayers=\(childLanguageLayers)]"
    }
}

private extension TreeSitterCapture {
    static func locationAndLengthSorting(_ lhs: TreeSitterCapture, _ rhs: TreeSitterCapture) -> Bool {
        if lhs.byteRange.location < rhs.byteRange.location {
            return true
        } else if lhs.byteRange.location > rhs.byteRange.location {
            return false
        } else {
            return lhs.byteRange.length > rhs.byteRange.length
        }
    }
}
