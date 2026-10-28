import Foundation

/// View state only. Collapsing never changes the source document or its undo history.
final class CodeFoldingController {
    private(set) var rangesByRow: [Int: TreeSitterFoldingRange] = [:]
    private(set) var collapsedRanges: Set<TreeSitterFoldingRange> = []

    var hiddenLineRanges: [ClosedRange<Int>] {
        collapsedRanges.map { $0.hiddenStartRow...$0.endRow }
    }

    func reset() {
        rangesByRow = [:]
        collapsedRanges = []
    }

    func update(_ ranges: [TreeSitterFoldingRange], lineCount: Int) {
        var byRow: [Int: TreeSitterFoldingRange] = [:]
        for range in ranges where range.startRow >= 0 && range.hiddenStartRow > range.startRow
            && range.endRow >= range.hiddenStartRow && range.endRow < lineCount {
            if let existing = byRow[range.startRow], existing.endRow >= range.endRow { continue }
            byRow[range.startRow] = range
        }
        rangesByRow = byRow
        collapsedRanges.formIntersection(Set(byRow.values))
    }

    @discardableResult
    func toggle(at row: Int) -> TreeSitterFoldingRange? {
        guard let range = rangesByRow[row] else {
            return nil
        }
        if !collapsedRanges.insert(range).inserted { collapsedRanges.remove(range) }
        return range
    }

    @discardableResult
    func reveal(row: Int) -> Bool {
        let previous = collapsedRanges.count
        collapsedRanges = collapsedRanges.filter { row < $0.hiddenStartRow || row > $0.endRow }
        return previous != collapsedRanges.count
    }

    /// Keep unaffected folds usable while a fresh query runs. Edits touching a boundary
    /// discard that candidate; edits before it translate its document rows.
    func apply(_ change: TextChange) {
        let start = change.startLinePosition.row
        let oldEnd = change.oldEndLinePosition.row
        let newEnd = change.newEndLinePosition.row
        let delta = newEnd - oldEnd
        func translated(_ range: TreeSitterFoldingRange) -> TreeSitterFoldingRange? {
            if oldEnd < range.startRow {
                return TreeSitterFoldingRange(startRow: range.startRow + delta,
                                              hiddenStartRow: range.hiddenStartRow + delta,
                                              endRow: range.endRow + delta)
            }
            if start > range.endRow {
                return range
            }
            if start > range.startRow && oldEnd < range.endRow {
                return TreeSitterFoldingRange(startRow: range.startRow,
                                              hiddenStartRow: range.hiddenStartRow,
                                              endRow: range.endRow + delta)
            }
            return nil
        }
        collapsedRanges = Set(collapsedRanges.compactMap(translated))
        rangesByRow = Dictionary(rangesByRow.values.compactMap(translated).map { ($0.startRow, $0) }) { first, second in
            first.endRow >= second.endRow ? first : second
        }
    }
}
