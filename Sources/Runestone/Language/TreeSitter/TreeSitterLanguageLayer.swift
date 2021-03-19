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
    private var childLanguageLayers: [String: TreeSitterLanguageLayer] = [:]
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

    func languageHierarchy() -> String {
        var str = ""
        if let rootNode = tree?.rootNode {
            str += "⬤: \(rootNode.byteRange.lowerBound.value) - \(rootNode.byteRange.upperBound.value)"
        } else {
            str += "⬤"
        }
        if !childLanguageLayers.isEmpty {
            str += "\n"
            str += childLanguageHierarchy(indent: 1)
        }
        return str
    }

    private func childLanguageHierarchy(indent: Int) -> String {
        var str = ""
        let languageNames = childLanguageLayers.keys
        for (idx, languageName) in languageNames.enumerated() {
            let indentStr = String(repeating: "  ", count: indent)
            let childLanguageLayer = childLanguageLayers[languageName]!
            if let rootNode = childLanguageLayer.tree?.rootNode {
                str += indentStr + "\(languageName): \(rootNode.byteRange.lowerBound.value) - \(rootNode.byteRange.upperBound.value)"
            } else {
                str += indentStr + "\(languageName)"
            }
            if !childLanguageLayer.childLanguageLayers.isEmpty {
                str += "\n"
                str += childLanguageLayer.childLanguageHierarchy(indent: indent + 1)
            }
            if idx < languageNames.count - 1 {
                str += indentStr + "\n"
            }
        }
        return str
    }
}

// MARK: - Parsing
extension TreeSitterLanguageLayer {
    func parse(_ text: String) {
        let ranges = [rootNode?.textRange].compactMap { $0 }
        prepareParser(toParse: ranges)
        parseAndUpdateChildLayers(text: text)
    }

    func apply(_ edit: TreeSitterInputEdit) -> LanguageModeTextChangeResult {
        // Apply edit to tree.
        let oldTree = tree
        tree?.apply(edit)
        let ranges = [rootNode?.textRange].compactMap { $0 }
        prepareParser(toParse: ranges)
        tree = parser.parse(oldTree: tree)
        var rows: Set<Int> = []
        // Apply edit to injected languages.
        for (_, childLanguageLayer) in childLanguageLayers {
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

    func node(at linePosition: LinePosition) -> TreeSitterNode? {
        let point = TreeSitterTextPoint(linePosition)
        guard var node = rootNode?.descendantForRange(from: point, to: point) else {
            return nil
        }
        for (_, childLanguageLayer) in childLanguageLayers {
            if let childNode = childLanguageLayer.node(at: linePosition), childNode.contains(point) {
                node = childNode
            }
        }
        return node
    }

    private func prepareParser(toParse ranges: [TreeSitterTextRange]) {
        parser.language = language.languagePointer
        if !ranges.isEmpty && parentLanguageLayer != nil {
            parser.setIncludedRanges(ranges)
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
            // Create language layers for each group of captures.
            let groups = Dictionary(compactGrouping: captures) { $0.injectionLanguage }
            for (languageName, captures) in groups {
                if let childLanguageLayer = childLanguageLayer(named: languageName) {
                    let ranges = captures.map { $0.node.textRange }
                    childLanguageLayer.prepareParser(toParse: ranges)
                    childLanguageLayer.parseAndUpdateChildLayers(text: text)
                }
            }
        }
    }
}

// MARK: - Syntax Highlighting
extension TreeSitterLanguageLayer {
    func captures(in range: ByteRange) -> [TreeSitterCapture] {
        let matches = matches(in: range)
        var captures = validCaptures(in: matches)
        captures.sort(by: TreeSitterCapture.captureLayerSorting)
        return captures
    }

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
        let matchesInChildren = childLanguageLayers.values.reduce([]) { $0 + $1.matches(in: range) }
        return matches + matchesInChildren
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
}

// MARK: - Child Language Layers
private extension TreeSitterLanguageLayer {
    @discardableResult
    private func childLanguageLayer(named languageName: String) -> TreeSitterLanguageLayer? {
        if let childLanguageLayer = childLanguageLayers[languageName] {
            return childLanguageLayer
        } else if let language = language.injectedLanguageProvider?.treeSitterLanguage(named: languageName) {
            let childLanguageLayer = TreeSitterLanguageLayer(language: language, parser: parser, stringView: stringView, lineManager: lineManager)
            childLanguageLayer.parentLanguageLayer = self
            childLanguageLayers[languageName] = childLanguageLayer
            return childLanguageLayer
        } else {
            return nil
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
        // Remove layers that no longer has any content
        let keysToBeRemoved: [String] = childLanguageLayers.compactMap { key, childLanguageLayer in
            if let rootNode = childLanguageLayer.rootNode {
                if rootNode.byteRange.length <= ByteCount(0) {
                    return key
                } else {
                    return nil
                }
            } else {
                return key
            }
        }
        for keyToBeRemoved in keysToBeRemoved {
            childLanguageLayers.removeValue(forKey: keyToBeRemoved)
        }
        // Update layers for current captures
        let groups = Dictionary(compactGrouping: captures) { $0.injectionLanguage }
        for (languageName, captures) in groups {
            if let childLanguageLayer = childLanguageLayer(named: languageName) {
                let ranges = captures.map { $0.node.textRange }
                childLanguageLayer.prepareParser(toParse: ranges)
                childLanguageLayer.tree = childLanguageLayer.parser.parse(oldTree: childLanguageLayer.tree)
            }
        }
        if parentLanguageLayer == nil {
            print(languageHierarchy())
        }
    }
}

// MARK: - Indentation
extension TreeSitterLanguageLayer {
    func shouldInsertDoubleLineBreak(replacingRangeFrom startLinePosition: LinePosition, to endLinePosition: LinePosition) -> Bool {
        let languageLayer = lowestLayer(containing: startLinePosition)
        return languageLayer._shouldInsertDoubleLineBreak(replacingRangeFrom: startLinePosition, to: endLinePosition)
    }

    func currentIndentLevel(of line: DocumentLineNode, using indentBehavior: EditorIndentBehavior) -> Int {
        let linePosition = LinePosition(row: line.index, column: 0)
        let languageLayer = lowestLayer(containing: linePosition)
        return languageLayer._currentIndentLevel(of: line, using: indentBehavior)
    }

    func suggestedIndentLevel(of line: DocumentLineNode, using indentBehavior: EditorIndentBehavior) -> Int {
        let linePosition = LinePosition(row: line.index, column: 0)
        let languageLayer = lowestLayer(containing: linePosition)
        return languageLayer._suggestedIndentLevel(of: line, using: indentBehavior)
    }

    func suggestedIndentLevel(at linePosition: LinePosition, using indentBehavior: EditorIndentBehavior) -> Int {
        let languageLayer = lowestLayer(containing: linePosition)
        return languageLayer._suggestedIndentLevel(at: linePosition, using: indentBehavior)
    }

    func indentLevelForInsertingLineBreak(at linePosition: LinePosition, using indentBehavior: EditorIndentBehavior) -> Int {
        let languageLayer = lowestLayer(containing: linePosition)
        return languageLayer._indentLevelForInsertingLineBreak(at: linePosition, using: indentBehavior)
    }

    private func _shouldInsertDoubleLineBreak(replacingRangeFrom startLinePosition: LinePosition, to endLinePosition: LinePosition) -> Bool {
        let indentationController = TreeSitterIndentController(languageLayer: self, indentationScopes: indentationScopes, stringView: stringView, lineManager: lineManager)
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

    private func _currentIndentLevel(of line: DocumentLineNode, using indentBehavior: EditorIndentBehavior) -> Int {
        let indentController = TreeSitterIndentController(languageLayer: self, indentationScopes: indentationScopes, stringView: stringView, lineManager: lineManager)
        return indentController.currentIndentLevel(of: line, using: indentBehavior)
    }

    private func _suggestedIndentLevel(of line: DocumentLineNode, using indentBehavior: EditorIndentBehavior) -> Int {
        let indentController = TreeSitterIndentController(languageLayer: self, indentationScopes: indentationScopes, stringView: stringView, lineManager: lineManager)
        let linePosition = startingLinePosition(of: line)
        return indentController.suggestedIndentLevel(at: linePosition, using: indentBehavior)
    }

    private func _suggestedIndentLevel(at linePosition: LinePosition, using indentBehavior: EditorIndentBehavior) -> Int {
        let indentController = TreeSitterIndentController(languageLayer: self, indentationScopes: indentationScopes, stringView: stringView, lineManager: lineManager)
        if let indentationScopes = indentationScopes, indentationScopes.indentIsDeterminedByLineStart {
            let line = lineManager.line(atRow: linePosition.row)
            let linePosition = startingLinePosition(of: line)
            return indentController.suggestedIndentLevel(at: linePosition, using: indentBehavior)
        } else {
            return indentController.suggestedIndentLevel(at: linePosition, using: indentBehavior)
        }
    }

    private func _indentLevelForInsertingLineBreak(at linePosition: LinePosition, using indentBehavior: EditorIndentBehavior) -> Int {
        let indentController = TreeSitterIndentController(languageLayer: self, indentationScopes: indentationScopes, stringView: stringView, lineManager: lineManager)
        if let indentationScopes = indentationScopes, indentationScopes.indentIsDeterminedByLineStart {
            let line = lineManager.line(atRow: linePosition.row)
            let linePosition = startingLinePosition(of: line)
            return indentController.indentLevelForInsertingLineBreak(at: linePosition, using: indentBehavior)
        } else {
            return indentController.indentLevelForInsertingLineBreak(at: linePosition, using: indentBehavior)
        }
    }
}

// MARK: - Misc
private extension TreeSitterLanguageLayer {
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

    private func lowestLayer(containing linePosition: LinePosition) -> TreeSitterLanguageLayer {
        let textPoint = TreeSitterTextPoint(linePosition)
        for (_, childLanguageLayer) in childLanguageLayers {
            if let tree = childLanguageLayer.tree {
                if tree.rootNode.contains(textPoint) {
                    return childLanguageLayer.lowestLayer(containing: linePosition)
                }
            }
        }
        return self
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
        let containsStart = point.row > startPoint.row || (point.row == startPoint.row && point.column >= startPoint.column)
        let containsEnd = point.row < endPoint.row || (point.row == endPoint.row && point.column <= endPoint.column)
        return containsStart && containsEnd
    }
}

private extension TreeSitterCapture {
    var injectionLanguage: String? {
        return properties["injection.language"]
    }
}
