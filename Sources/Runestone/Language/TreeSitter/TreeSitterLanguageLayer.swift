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
    private let node: TreeSitterNode?
    private var childLanguageLayers: [TreeSitterLanguageLayer] = []
    private var tree: TreeSitterTree?

    init(language: TreeSitterLanguage, parser: TreeSitterParser, node: TreeSitterNode? = nil) {
        self.language = language
        self.parser = parser
        self.node = node
    }

    func parse(_ text: String) {
        prepareParser()
        tree = parser.parse(text)
        childLanguageLayers.removeAll()
        if let injectionsQuery = language.injectionsQuery, let node = tree?.rootNode {
            let injectionsQueryCursor = TreeSitterQueryCursor(query: injectionsQuery, node: node)
            injectionsQueryCursor.execute()
            let captures = injectionsQueryCursor.allCaptures()
            for capture in captures {
                if let childLanguageLayer = insertLanguageLayer(forInjectionCapture: capture) {
                    childLanguageLayer.parse(text)
                }
            }
        }
    }

    func apply(_ edit: TreeSitterInputEdit) -> LanguageModeTextChangeResult {
        let oldTree = tree
        prepareParser()
        tree?.apply(edit)
        tree = parser.parse(oldTree: oldTree)
        var lineIndices = applyEditToChildren(edit)
        if let oldTree = oldTree, let newTree = tree {
            let changedRanges = oldTree.rangesChanged(comparingTo: newTree)
            for changedRange in changedRanges {
                for lineIndex in changedRange.startPoint.row ... changedRange.endPoint.row {
                    lineIndices.insert(Int(lineIndex))
                }
            }
        }
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
        return captures + childCaptures
    }
}

private extension TreeSitterLanguageLayer {
    private func prepareParser() {
        parser.language = language.languagePointer
        if let node = node {
            let range = TreeSitterTextRange(startPoint: node.startPoint, endPoint: node.endPoint, startByte: node.startByte, endByte: node.endByte)
            parser.setIncludedRanges([range])
        } else {
            parser.removeAllIncludedRanges()
        }
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
        let childLanguageLayer = TreeSitterLanguageLayer(language: language, parser: parser, node: capture.node)
        childLanguageLayers.append(childLanguageLayer)
        return childLanguageLayer
    }
}

extension TreeSitterLanguageLayer: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[TreeSitterLanguageLayer node=\(node?.debugDescription ?? "") childLanguageLayers=\(childLanguageLayers)]"
    }
}
