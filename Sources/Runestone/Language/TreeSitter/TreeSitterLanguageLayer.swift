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

    private let lineManager: LineManager
    private let language: TreeSitterLanguage
    private let indentationScopes: TreeSitterIndentationScopes?
    private let parser: TreeSitterParser
    private let stringView: StringView
    private var childLanguageLayers: [TreeSitterLanguageLayer] = []
    private weak var parentLanguageLayer: TreeSitterLanguageLayer?
    private var tree: TreeSitterTree?
    private var isEmpty: Bool {
        if let rootNode = rootNode {
            return rootNode.endByte - rootNode.startByte <= ByteCount(0)
        } else {
            return true
        }
    }

    init(language: TreeSitterLanguage, parser: TreeSitterParser, stringView: StringView, lineManager: LineManager) {
        self.language = language
        self.indentationScopes = language.indentationScopes
        self.parser = parser
        self.stringView = stringView
        self.lineManager = lineManager
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
        var rows: Set<Int> = []
        // Apply edit to injected languages.
        for childLanguageLayer in childLanguageLayers {
            let childResult = childLanguageLayer.apply(edit)
            rows.formUnion(childResult.changedRows)
        }
        // Gather changed line indices.
        if let oldTree = oldTree, let newTree = tree {
            let changedRanges = oldTree.rangesChanged(comparingTo: newTree)
            for changedRange in changedRanges {
                for row in changedRange.startPoint.row ... changedRange.endPoint.row {
                    rows.insert(Int(row))
                }
            }
        }
        updateChildLayers()
        return LanguageModeTextChangeResult(changedRows: rows)
    }

    func captures(in range: ByteRange) -> [TreeSitterCapture] {
        let matches = matches(in: range)
        var captures = validCaptures(in: matches)
        captures.sort(by: TreeSitterCapture.captureLayerSorting)
        return captures
    }

    func node(at linePosition: LinePosition) -> TreeSitterNode? {
        let point = TreeSitterTextPoint(linePosition)
        guard var node = rootNode?.descendantForRange(from: point, to: point) else {
            return nil
        }
        for childLanguageLayer in childLanguageLayers {
            if let childNode = childLanguageLayer.node(at: linePosition), childNode.contains(point) {
                node = childNode
            }
        }
        return node
    }

    func shouldInsertDoubleLineBreak(replacingRangeFrom startLinePosition: LinePosition, to endLinePosition: LinePosition) -> Bool {
        guard let indentationController = createIndentController() else {
            return false
        }
        guard let startNode = node(at: startLinePosition), let startIndentingNode = indentationController.firstNodeAddingAdditionalLineBreak(from: startNode) else {
            return false
        }
        // Selected range must start within the range of the indenting now.
        guard startIndentingNode.startPoint.row == startLinePosition.row && startLinePosition.column >= startIndentingNode.startPoint.column else {
            return false
        }
        guard let endNode = node(at: startLinePosition), let endIndentingNode = indentationController.firstNodeAddingAdditionalLineBreak(from: endNode) else {
            return false
        }
        // Note at the end of the selection must be the same note as at the start of the selection.
        guard startIndentingNode == endIndentingNode else {
            return false
        }
        // Selected range must end within the range of the indenting now.
        return endIndentingNode.endPoint.row == endLinePosition.row && endLinePosition.column < endIndentingNode.endPoint.column
    }

    func currentIndentLevel(of line: DocumentLineNode, using indentBehavior: EditorIndentBehavior) -> Int {
        guard let indentController = createIndentController() else {
            return 0
        }
        return indentController.currentIndentLevel(of: line, using: indentBehavior)
    }

    func suggestedIndentLevel(of line: DocumentLineNode, using indentBehavior: EditorIndentBehavior) -> Int {
        guard let indentController = createIndentController() else {
            return 0
        }
        let linePosition = startingLinePosition(of: line)
        return indentController.suggestedIndentLevel(at: linePosition, using: indentBehavior)
    }

    func suggestedIndentLevel(at linePosition: LinePosition, using indentBehavior: EditorIndentBehavior) -> Int {
        guard let indentController = createIndentController() else {
            return 0
        }
        if let indentationScopes = indentationScopes, indentationScopes.indentIsDeterminedByLineStart {
            let line = lineManager.line(atRow: linePosition.row)
            let linePosition = startingLinePosition(of: line)
            return indentController.suggestedIndentLevel(at: linePosition, using: indentBehavior)
        } else {
            return indentController.suggestedIndentLevel(at: linePosition, using: indentBehavior)
        }
    }

    func indentLevelForInsertingLineBreak(at linePosition: LinePosition, using indentBehavior: EditorIndentBehavior) -> Int {
        guard let indentController = createIndentController() else {
            return 0
        }
        if let indentationScopes = indentationScopes, indentationScopes.indentIsDeterminedByLineStart {
            let line = lineManager.line(atRow: linePosition.row)
            let linePosition = startingLinePosition(of: line)
            return indentController.indentLevelForInsertingLineBreak(at: linePosition, using: indentBehavior)
        } else {
            return indentController.indentLevelForInsertingLineBreak(at: linePosition, using: indentBehavior)
        }
    }
}

private extension TreeSitterLanguageLayer {
    private func matches(in range: ByteRange) -> [TreeSitterQueryMatch] {
        guard let tree = tree else {
            return []
        }
        guard let query = language.highlightsQuery else {
            return []
        }
        let queryCursor = TreeSitterQueryCursor(query: query, node: tree.rootNode)
        queryCursor.setQueryRange(range)
        queryCursor.execute()
        let matches = queryCursor.allMatches()
        let matchesInChildren = childLanguageLayers.reduce([]) { $0 + $1.matches(in: range) }
        return matches + matchesInChildren
    }

    private func prepareParserToParse(from rootNode: TreeSitterNode?) {
        parser.language = language.languagePointer
        if let node = rootNode, parentLanguageLayer != nil {
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

    private func validCaptures(in matches: [TreeSitterQueryMatch]) -> [TreeSitterCapture] {
        var result: [TreeSitterCapture] = []
        for match in matches {
            let predicateEvaluator = TreeSitterTextPredicatesEvaluator(match: match, stringView: stringView)
            let captures = match.captures.filter { capture in
                return predicateEvaluator.evaluatePredicates(in: capture)
            }
            result.append(contentsOf: captures)
        }
        return result
    }

    @discardableResult
    private func insertLanguageLayer(forInjectionCapture capture: TreeSitterCapture) -> TreeSitterLanguageLayer? {
        guard let languageName = capture.properties["injection.language"] else {
            return nil
        }
        guard let language = language.injectedLanguageProvider?.treeSitterLanguage(named: languageName) else {
            return nil
        }
        let childLanguageLayer = TreeSitterLanguageLayer(language: language, parser: parser, stringView: stringView, lineManager: lineManager)
        childLanguageLayer.parentLanguageLayer = self
        childLanguageLayers.append(childLanguageLayer)
        return childLanguageLayer
    }

    private func createIndentController() -> TreeSitterIndentController? {
        guard let indentationScopes = indentationScopes else {
            return nil
        }
        return TreeSitterIndentController(
            languageLayer: self,
            indentationScopes: indentationScopes,
            stringView: stringView,
            lineManager: lineManager)
    }

    private func startingLinePosition(of line: DocumentLineNode) -> LinePosition {
        // Find the first character that is not a whitespace
        let range = NSRange(location: line.location, length: line.data.totalLength)
        let string = stringView.substring(in: range)
        var currentColumn = 0
        let whitespaceCharacters = Set([Symbol.Character.space, Symbol.Character.tab])
        if let stringIndex = string.firstIndex(where: { !whitespaceCharacters.contains($0) }) {
            let utf16View = string.utf16
            if let utf16Index = stringIndex.samePosition(in: string.utf16) {
                currentColumn = utf16View.distance(from: utf16View.startIndex, to: utf16Index)
            }
        }
        return LinePosition(row: line.index, column: currentColumn)
    }
}

extension TreeSitterLanguageLayer: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[TreeSitterLanguageLayer node=\(rootNode?.debugDescription ?? "") childLanguageLayers=\(childLanguageLayers)]"
    }
}

private extension TreeSitterCapture {
    static func captureLayerSorting(_ lhs: TreeSitterCapture, _ rhs: TreeSitterCapture) -> Bool {
        // We sort the captures by three parameters:
        // 1. The location. Captures that are early in the text should be sorted first.
        // 2. The length of the capture. If two captures start at the same location, then we sort the longest capture first.
        //    Short captures that start at that location adds another "layer" of capturing on top of a previous capture.
        // 3. The number of components in the name. E.g. "variable.builtin" is sorted after "variable" as the styling of "variable.builtin"
        //    should be applied after applying the styling of "variable", since it's a specialization.
        if lhs.byteRange.location < rhs.byteRange.location {
            return true
        } else if lhs.byteRange.location > rhs.byteRange.location {
            return false
        } else if lhs.byteRange.length > rhs.byteRange.length {
            return true
        } else {
            return lhs.nameComponentCount < rhs.nameComponentCount
        }
    }
}

private extension TreeSitterQueryCursor {
    func allCaptures() -> [TreeSitterCapture] {
        return allMatches().reduce([]) { $0 + $1.captures }
    }
}

private extension TreeSitterNode {
    func contains(_ point: TreeSitterTextPoint) -> Bool {
        return point.row >= startPoint.row && point.column >= startPoint.column
            && point.row <= endPoint.row && point.column <= endPoint.column
    }
}
