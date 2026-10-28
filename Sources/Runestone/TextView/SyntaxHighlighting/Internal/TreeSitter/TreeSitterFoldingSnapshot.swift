import Foundation
import TreeSitter

/// Document rows, independent of the lifetime of any syntax tree.
struct TreeSitterFoldingRange: Equatable, Hashable {
    let startRow: Int
    let hiddenStartRow: Int
    let endRow: Int

    init(startRow: Int, hiddenStartRow: Int? = nil, endRow: Int) {
        self.startRow = startRow
        self.hiddenStartRow = hiddenStartRow ?? startRow + 1
        self.endRow = endRow
    }
}

/// Owns copies of all fold-enabled trees, including injected languages. It does
/// not depend on highlights queries or retain nodes after returning its result.
final class TreeSitterFoldingSnapshot {
    struct Layer {
        let tree: TreeSitterTree
        let query: TreeSitterQuery
    }

    struct Heading {
        let startRow: Int
        let headerEndRow: Int
        let level: Int
        let container: Int
        let containerEndRow: Int
    }

    private let layers: [Layer]
    private let stringView: StringView

    init(layers: [Layer], stringView: StringView) {
        self.layers = layers
        self.stringView = stringView
    }

    func ranges(isCancelled: () -> Bool = { false }) -> [TreeSitterFoldingRange] {
        guard !layers.isEmpty, !isCancelled() else {
            return []
        }
        let lines = FoldingText(string: stringView.string, isCancelled: isCancelled)
        guard !isCancelled() else {
            return []
        }
        var ranges: [TreeSitterFoldingRange] = []
        for layer in layers {
            guard !isCancelled() else {
                return []
            }
            ranges += self.ranges(in: layer, lines: lines, isCancelled: isCancelled)
        }
        guard !isCancelled() else {
            return []
        }
        return Array(Set(ranges)).sorted { lhs, rhs in
            lhs.startRow == rhs.startRow ? lhs.endRow > rhs.endRow : lhs.startRow < rhs.startRow
        }
    }

    private func ranges(in layer: Layer, lines: FoldingText, isCancelled: () -> Bool) -> [TreeSitterFoldingRange] {
        guard let cursor = ts_query_cursor_new() else {
            return []
        }
        defer { ts_query_cursor_delete(cursor) }
        ts_query_cursor_exec(cursor, layer.query.pointer, layer.tree.rootNode.rawValue)
        var rawMatch = TSQueryMatch(id: 0, pattern_index: 0, capture_count: 0, captures: nil)
        var result: [TreeSitterFoldingRange] = []
        var headings: [Heading] = []
        var containerIDs: [TreeSitterNode: Int] = [:]
        while !isCancelled(), ts_query_cursor_next_match(cursor, &rawMatch) {
            let predicates = layer.query.predicates(forPatternIndex: UInt32(rawMatch.pattern_index))
            // Range directives belong to folding. The highlighting predicate
            // evaluator continues rejecting unsupported directives as before.
            let conditions = predicates.filter { !["trim!", "offset!", "not-has-parent?", "has-parent?"].contains($0.name) }
            let rawCaptures = UnsafeBufferPointer(start: rawMatch.captures, count: Int(rawMatch.capture_count))
            let captures = rawCaptures.map { capture in
                TreeSitterCapture(node: TreeSitterNode(node: capture.node), index: capture.index,
                                  name: layer.query.captureName(forId: capture.index), predicates: conditions)
            }
            let match = TreeSitterQueryMatch(captures: captures)
            let evaluator = TreeSitterTextPredicatesEvaluator(match: match, stringView: stringView)
            guard captures.allSatisfy({ evaluator.evaluatePredicates(in: $0) }) else { continue }
            guard parentPredicatesMatch(predicates, captures: captures) else { continue }
            let groups = Dictionary(grouping: captures.filter { $0.name == "fold" || $0.name == "fold.heading" }, by: \.index)
            for (index, group) in groups {
                guard !isCancelled() else {
                    return []
                }
                if group.first?.name == "fold.heading" {
                    for capture in group {
                        guard let level = headingLevel(capture.node) else { continue }
                        let container = headingContainer(capture.node, root: layer.tree.rootNode)
                        let containerID = containerIDs[container] ?? containerIDs.count
                        containerIDs[container] = containerID
                        headings.append(Heading(startRow: Int(capture.node.startPoint.row),
                                                headerEndRow: lastRow(of: capture.node), level: level,
                                                container: containerID, containerEndRow: lastRow(of: container)))
                    }
                    continue
                }
                if let range = foldingRange(group, index: index, predicates: predicates, lines: lines) { result.append(range) }
            }
        }
        result += Self.sectionRanges(headings)
        return isCancelled() ? [] : result
    }

    private func foldingRange(_ group: [TreeSitterCapture], index: UInt32,
                              predicates: [TreeSitterPredicate], lines: FoldingText) -> TreeSitterFoldingRange? {
        guard let start = group.map({ $0.byteRange.location.utf16Length }).min(),
              let end = group.map({ $0.byteRange.upperBound.utf16Length }).max() else {
            return nil
        }
        var extent: Range<Int>? = start..<end
        for predicate in predicates where predicate.name == "trim!" || predicate.name == "offset!" {
            guard let first = predicate.steps.first, case .capture(let target) = first, target == index else { continue }
            guard let current = extent else { break }
            extent = applying(predicate, to: current, lines: lines)
        }
        guard let extent = extent, !extent.isEmpty else {
            return nil
        }
        let startRow = lines.row(at: extent.lowerBound)
        let endRow = lines.row(at: extent.upperBound - 1)
        return endRow > startRow ? .init(startRow: startRow, endRow: endRow) : nil
    }

    private func applying(_ predicate: TreeSitterPredicate, to range: Range<Int>, lines: FoldingText) -> Range<Int>? {
        let values = predicate.steps.dropFirst().compactMap { step -> Int? in
            guard case .string(let value) = step else {
                return nil
            }
            return Int(value)
        }
        if predicate.name == "offset!" {
            return values.count == 4 && predicate.steps.count == 5 ? lines.offset(range, values: values) : nil
        }
        let flags = predicate.steps.count == 1 ? [0, 0, 1, 0] : values
        let valid = (predicate.steps.count == 1 || predicate.steps.count == 5)
            && flags.count == 4 && flags.allSatisfy { $0 == 0 || $0 == 1 }
        return valid ? lines.trim(range, flags: flags) : nil
    }

    private func parentPredicatesMatch(_ predicates: [TreeSitterPredicate], captures: [TreeSitterCapture]) -> Bool {
        for predicate in predicates where predicate.name == "not-has-parent?" || predicate.name == "has-parent?" {
            guard let first = predicate.steps.first, case .capture(let target) = first else {
                return false
            }
            let types = predicate.steps.dropFirst().compactMap { step -> String? in
                guard case .string(let type) = step else {
                    return nil
                }
                return type
            }
            let matchingCaptures = captures.filter { $0.index == target }
            guard !types.isEmpty, !matchingCaptures.isEmpty else {
                return false
            }
            for capture in matchingCaptures {
                let matches = types.contains(capture.node.parent?.type ?? "")
                if matches != (predicate.name == "has-parent?") {
                    return false
                }
            }
        }
        return true
    }

    /// Sections use heading levels instead of the grammar's `section` nodes:
    /// some Markdown grammars omit Setext headings from that hierarchy.
    static func sectionRanges(_ headings: [Heading]) -> [TreeSitterFoldingRange] {
        var result: [TreeSitterFoldingRange] = []
        for group in Dictionary(grouping: headings, by: \.container).values {
            let ordered = group.sorted { $0.startRow < $1.startRow }
            var stack: [Heading] = []
            func append(_ heading: Heading, endingAt endRow: Int) {
                let lastRow = min(endRow, heading.containerEndRow)
                if lastRow > heading.headerEndRow {
                    result.append(.init(startRow: heading.startRow, hiddenStartRow: heading.headerEndRow + 1, endRow: lastRow))
                }
            }
            for heading in ordered {
                while let previous = stack.last, previous.level >= heading.level {
                    append(stack.removeLast(), endingAt: heading.startRow - 1)
                }
                stack.append(heading)
            }
            for heading in stack { append(heading, endingAt: heading.containerEndRow) }
        }
        return result.sorted { $0.startRow < $1.startRow }
    }

    private func headingLevel(_ node: TreeSitterNode) -> Int? {
        for index in 0..<node.childCount {
            guard let type = node.child(at: index)?.type else { continue }
            for level in 1...6 where type == "atx_h\(level)_marker" || type == "setext_h\(level)_underline" { return level }
        }
        return nil
    }

    private func headingContainer(_ node: TreeSitterNode, root: TreeSitterNode) -> TreeSitterNode {
        var parent = node.parent
        while let current = parent {
            if ["document", "block_quote", "list_item"].contains(current.type ?? "") {
                return current
            }
            parent = current.parent
        }
        return root
    }

    private func lastRow(of node: TreeSitterNode) -> Int {
        let end = node.endPoint
        return max(Int(node.startPoint.row), Int(end.row) - (end.column == 0 ? 1 : 0))
    }
}

/// Maps immutable UTF-16 source positions to Tree-sitter's LF-delimited rows.
private final class FoldingText {
    let string: NSString
    private var starts = [0]

    init(string: NSString, isCancelled: () -> Bool) {
        self.string = string
        for index in 0..<string.length {
            if index % 4_096 == 0, isCancelled() {
                return
            }
            if string.character(at: index) == 10 { starts.append(index + 1) }
        }
    }

    func row(at offset: Int) -> Int {
        var lower = 0
        var upper = starts.count
        while lower + 1 < upper {
            let middle = (lower + upper) / 2
            if starts[middle] <= offset { lower = middle } else { upper = middle }
        }
        return lower
    }

    private func end(of row: Int) -> Int { row + 1 < starts.count ? starts[row + 1] : string.length }

    private func contentEnd(of row: Int) -> Int {
        row + 1 < starts.count ? starts[row + 1] - 1 : string.length
    }

    func offset(_ range: Range<Int>, values: [Int]) -> Range<Int>? {
        let startRow = row(at: range.lowerBound)
        let endRow = row(at: range.upperBound)
        let newStartRow = startRow + values[0]
        let newEndRow = endRow + values[2]
        guard starts.indices.contains(newStartRow), starts.indices.contains(newEndRow) else {
            return nil
        }
        // Columns use the editor's UTF-16 coordinates; row offsets preserve the
        // existing column just as Tree-sitter query offset directives do.
        let startColumn = range.lowerBound - starts[startRow] + values[1]
        let endColumn = range.upperBound - starts[endRow] + values[3]
        guard startColumn >= 0, endColumn >= 0 else {
            return nil
        }
        let start = starts[newStartRow] + startColumn
        let finish = starts[newEndRow] + endColumn
        guard start <= end(of: newStartRow), finish <= end(of: newEndRow), start < finish else {
            return nil
        }
        return start..<finish
    }

    func trim(_ range: Range<Int>, flags: [Int]) -> Range<Int>? {
        guard range.lowerBound >= 0, range.upperBound <= string.length else {
            return nil
        }
        var start = range.lowerBound
        var finish = range.upperBound
        if flags[2] == 1 {
            finish = trimmingEndLines(range)
        }
        if flags[3] == 1 {
            let lineStart = starts[row(at: finish)]
            while finish > max(start, lineStart) && isHorizontalWhitespace(at: finish - 1) { finish -= 1 }
        }
        if flags[0] == 1 {
            while start < finish {
                let startRow = row(at: start)
                let lineEnd = min(contentEnd(of: startRow), finish)
                guard isBlank(start..<max(start, lineEnd)) else { break }
                start = min(end(of: startRow), finish)
            }
        }
        if flags[1] == 1 {
            let lineEnd = contentEnd(of: row(at: start))
            while start < min(finish, lineEnd) && isHorizontalWhitespace(at: start) { start += 1 }
        }
        return start < finish ? start..<finish : nil
    }

    private func trimmingEndLines(_ range: Range<Int>) -> Int {
        let start = range.lowerBound
        var finish = range.upperBound
        var endRow = row(at: finish)
        while start < finish {
            let previous = max(starts[endRow], start)
            let lineEnd = min(contentEnd(of: endRow), finish)
            guard isBlank(previous..<max(previous, lineEnd)) else { break }
            endRow -= 1
            finish = endRow >= row(at: start) ? max(start, contentEnd(of: endRow)) : start
        }
        return finish
    }

    private func isBlank(_ range: Range<Int>) -> Bool {
        string.substring(with: NSRange(location: range.lowerBound, length: range.count))
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isHorizontalWhitespace(at index: Int) -> Bool {
        guard let scalar = UnicodeScalar(string.character(at: index)) else {
            return false
        }
        return CharacterSet.whitespacesAndNewlines.contains(scalar)
    }
}
