//
//  TreeSitterLanguageLayer.swift
//  
//
//  Created by Simon Støvring on 16/02/2021.
//

import Foundation

protocol TreeSitterLanguageLayerDelegate: AnyObject {
    func treeSitterLanguageLayer(_ languageLayer: TreeSitterLanguageLayer, stringIn byteRange: ByteRange) -> String
}

final class TreeSitterLanguageLayer {
    weak var delegate: TreeSitterLanguageLayerDelegate?
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
        let queryCursor = TreeSitterQueryCursor(query: query, node: tree.rootNode)
        queryCursor.setQueryRange(range)
        queryCursor.execute()
        let matches = matchesInChildren(in: range) + queryCursor.allMatches()
        var validCaptures: [TreeSitterCapture] = []
        for match in matches {
            let predicateEvaluator = TreeSitterTextPredicatesEvaluator(match: match) { [weak self] byteRange in
                if let self = self {
                    return self.delegate?.treeSitterLanguageLayer(self, stringIn: byteRange)
                } else {
                    return nil
                }
            }
            for capture in match.captures {
                if predicateEvaluator.evaluatePredicates(in: capture) {
                    validCaptures.append(capture)
                }
            }
        }
        let sortedCaptures = validCaptures.sorted(by: TreeSitterCapture.byteRangeSorting)
        print("- - - - - - - - - - - - -")
        for capture in sortedCaptures {
            print(capture)
        }
        return sortedCaptures
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

    private func matchesInChildren(in range: ByteRange) -> [TreeSitterQueryMatch] {
        return childLanguageLayers.reduce([]) { result, childLanguageLayer in
            return result + childLanguageLayer.matchesInChildren(in: range)
        }
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
        childLanguageLayer.delegate = self
        childLanguageLayers.append(childLanguageLayer)
        return childLanguageLayer
    }
}

extension TreeSitterLanguageLayer: TreeSitterLanguageLayerDelegate {
    func treeSitterLanguageLayer(_ languageLayer: TreeSitterLanguageLayer, stringIn byteRange: ByteRange) -> String {
        return delegate!.treeSitterLanguageLayer(self, stringIn: byteRange)
    }
}

extension TreeSitterLanguageLayer: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[TreeSitterLanguageLayer node=\(rootNode?.debugDescription ?? "") childLanguageLayers=\(childLanguageLayers)]"
    }
}

private extension TreeSitterCapture {
    static func byteRangeSorting(_ lhs: TreeSitterCapture, _ rhs: TreeSitterCapture) -> Bool {
        if lhs.byteRange.location < rhs.byteRange.location {
            return true
        } else if lhs.byteRange.location > rhs.byteRange.location {
            return false
        } else {
            return lhs.byteRange.length > rhs.byteRange.length
        }
    }
}

private extension TreeSitterQueryCursor {
    func allCaptures() -> [TreeSitterCapture] {
        return allMatches().reduce([]) { $0 + $1.captures }
    }
}
