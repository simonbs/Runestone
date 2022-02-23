import Foundation

final class TreeSitterLanguageLayer {
    typealias LayerAndNodeTuple = (layer: TreeSitterLanguageLayer, node: TreeSitterNode)

    let language: TreeSitterInternalLanguage
    private(set) var tree: TreeSitterTree?
    var canHighlight: Bool {
        return parser.language != nil && tree != nil
    }

    private let lineManager: LineManager
    private let parser: TreeSitterParser
    private let stringView: StringView
    private var childLanguageLayers: [String: TreeSitterLanguageLayer] = [:]
    private weak var parentLanguageLayer: TreeSitterLanguageLayer?
    private let languageProvider: TreeSitterLanguageProvider?
    private var isEmpty: Bool {
        if let rootNode = tree?.rootNode {
            return rootNode.endByte - rootNode.startByte <= ByteCount(0)
        } else {
            return true
        }
    }

    init(language: TreeSitterInternalLanguage,
         languageProvider: TreeSitterLanguageProvider?,
         parser: TreeSitterParser,
         stringView: StringView,
         lineManager: LineManager) {
        self.language = language
        self.languageProvider = languageProvider
        self.parser = parser
        self.stringView = stringView
        self.lineManager = lineManager
    }
}

// MARK: - Parsing
extension TreeSitterLanguageLayer {
    func parse(_ text: NSString) {
        let ranges = [tree?.rootNode.textRange].compactMap { $0 }
        parse(ranges, from: text)
    }

    func apply(_ edit: TreeSitterInputEdit) -> LanguageModeTextChangeResult {
        let ranges = [tree?.rootNode.textRange].compactMap { $0 }
        return apply(edit, parsing: ranges)
    }

    func layerAndNode(at linePosition: LinePosition) -> LayerAndNodeTuple? {
        let point = TreeSitterTextPoint(linePosition)
        guard let node = tree?.rootNode.descendantForRange(from: point, to: point) else {
            return nil
        }
        var result: LayerAndNodeTuple = (layer: self, node: node)
        for (_, childLanguageLayer) in childLanguageLayers {
            if let childRootNode = childLanguageLayer.tree?.rootNode, childRootNode.contains(point) {
                if let childResult = childLanguageLayer.layerAndNode(at: linePosition) {
                    if childResult.node.byteRange.length < result.node.byteRange.length {
                        result = childResult
                    }
                }
            }
        }
        return result
    }

    private func apply(_ edit: TreeSitterInputEdit, parsing ranges: [TreeSitterTextRange] = []) -> LanguageModeTextChangeResult {
        // Apply edit to tree.
        let oldTree = tree
        tree?.apply(edit)
        prepareParser(toParse: ranges)
        tree = parser.parse(oldTree: tree)
        // Gather changed line indices.
        var changedRows: Set<Int> = []
        if let oldTree = oldTree, let newTree = tree {
            let changedRanges = oldTree.rangesChanged(comparingTo: newTree)
            for changedRange in changedRanges {
                let startRow = Int(changedRange.startPoint.row)
                let endRow = Int(changedRange.endPoint.row)
                changedRows.formUnion(startRow ... endRow)
            }
        }
        let childChangedRows = updateChildLayers(applying: edit)
        changedRows.formUnion(childChangedRows)
        return LanguageModeTextChangeResult(changedRows: changedRows)
    }

    private func prepareParser(toParse ranges: [TreeSitterTextRange]) {
        parser.language = language.languagePointer
        if !ranges.isEmpty && parentLanguageLayer != nil {
            parser.setIncludedRanges(ranges)
        } else {
            parser.removeAllIncludedRanges()
        }
    }

    private func parse(_ ranges: [TreeSitterTextRange], from text: NSString) {
        prepareParser(toParse: ranges)
        tree = parser.parse(text)
        childLanguageLayers.removeAll()
        if let injectionsQuery = language.injectionsQuery, let node = tree?.rootNode {
            let injectionsQueryCursor = TreeSitterQueryCursor(query: injectionsQuery, node: node)
            injectionsQueryCursor.execute()
            let captures = injectionsQueryCursor.allCaptures()
            let injectedLanguageGroups = injectedLanguageGroups(from: captures)
            for injectedLanguageGroup in injectedLanguageGroups {
                if let childLanguageLayer = childLanguageLayer(named: injectedLanguageGroup.languageName) {
                    childLanguageLayer.parse(injectedLanguageGroup.textRanges, from: text)
                }
            }
        }
    }
}

// MARK: - Syntax Highlighting
extension TreeSitterLanguageLayer {
    func captures(in range: ByteRange) -> [TreeSitterCapture] {
        guard !range.isEmpty else {
            return []
        }
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
        let matchesInChildren = childLanguageLayers.values.reduce(into: []) { $0 += $1.matches(in: range) }
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
        } else if let language = languageProvider?.treeSitterLanguage(named: languageName) {
            let childLanguageLayer = TreeSitterLanguageLayer(
                language: language.internalLanguage,
                languageProvider: languageProvider,
                parser: parser,
                stringView: stringView,
                lineManager: lineManager)
            childLanguageLayer.parentLanguageLayer = self
            childLanguageLayers[languageName] = childLanguageLayer
            return childLanguageLayer
        } else {
            return nil
        }
    }

    private func updateChildLayers(applying edit: TreeSitterInputEdit) -> Set<Int> {
        guard let injectionsQuery = language.injectionsQuery, let node = tree?.rootNode else {
            childLanguageLayers.removeAll()
            return []
        }
        let injectionsQueryCursor = TreeSitterQueryCursor(query: injectionsQuery, node: node)
        injectionsQueryCursor.execute()
        let captures = injectionsQueryCursor.allCaptures()
        let injectedLanguageGroups = injectedLanguageGroups(from: captures)
        let capturedLanguageNames = injectedLanguageGroups.map(\.languageName)
        let currentLanguageNames = Array(childLanguageLayers.keys)
        for languageName in currentLanguageNames {
            if !capturedLanguageNames.contains(languageName) {
                // Remove languages that we no longer have any captures for.
                childLanguageLayers.removeValue(forKey: languageName)
            } else if let rootNode = childLanguageLayers[languageName]?.tree?.rootNode, rootNode.byteRange.length <= 0 {
                // Remove layers that no longer has any content.
                childLanguageLayers.removeValue(forKey: languageName)
            }
        }
        // Update layers for current captures
        var changedRows: Set<Int> = []
        for injectedLanguageGroup in injectedLanguageGroups {
            if let childLanguageLayer = childLanguageLayer(named: injectedLanguageGroup.languageName) {
                let applyEditResult = childLanguageLayer.apply(edit, parsing: injectedLanguageGroup.textRanges)
                changedRows.formUnion(applyEditResult.changedRows)
            }
        }
        return changedRows
    }

    private func injectedLanguageGroups(from captures: [TreeSitterCapture]) -> [TreeSitterInjectedLanguageGroup] {
        let mapper = TreeSitterInjectedLanguageGroupMapper(captures: captures)
        mapper.delegate = self
        return mapper.makeGroups()
    }
}

// MARK: - TreeSitterInjectedLanguageGroupMapperDelegate
extension TreeSitterLanguageLayer: TreeSitterInjectedLanguageGroupMapperDelegate {
    func treeSitterInjectedLanguageGroupMapper(_ mapper: TreeSitterInjectedLanguageGroupMapper, textIn textRange: TreeSitterTextRange) -> String? {
        let byteRange = ByteRange(from: textRange.startByte, to: textRange.endByte)
        let range = NSRange(byteRange)
        return stringView.substring(in: range)
    }
}

// MARK: - Debugging Language Layers
extension TreeSitterLanguageLayer {
    func languageHierarchyStringRepresentation() -> String {
        var str = ""
        if let rootNode = tree?.rootNode {
            str += "● [\(rootNode.byteRange.lowerBound) - \(rootNode.byteRange.upperBound)]"
        } else {
            str += "●"
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
                str += indentStr + "\(languageName) [\(rootNode.byteRange.lowerBound) - \(rootNode.byteRange.upperBound)]"
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

extension TreeSitterLanguageLayer: CustomDebugStringConvertible {
    var debugDescription: String {
        return "[TreeSitterLanguageLayer node=\(tree?.rootNode.debugDescription ?? "") childLanguageLayers=\(childLanguageLayers)]"
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
        } else if lhs.byteRange.length < rhs.byteRange.length {
            return false
        } else {
            return lhs.nameComponentCount < rhs.nameComponentCount
        }
    }
}

private extension TreeSitterQueryCursor {
    func allCaptures() -> [TreeSitterCapture] {
        return allMatches().reduce(into: []) { $0 += $1.captures }
    }
}

private extension TreeSitterNode {
    func contains(_ point: TreeSitterTextPoint) -> Bool {
        let containsStart = point.row > startPoint.row || (point.row == startPoint.row && point.column >= startPoint.column)
        let containsEnd = point.row < endPoint.row || (point.row == endPoint.row && point.column <= endPoint.column)
        return containsStart && containsEnd
    }
}
