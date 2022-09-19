import Foundation

final class HighlightRectService {
    var lineManager: LineManager {
        didSet {
            if lineManager !== oldValue {
                highlightedRangesForLine.removeAll()
                highlightRectsForLine.removeAll()
                highlightedRangesForLine = createHighlightedRangesPerLine()
            }
        }
    }
    var highlightedRanges: [HighlightedRange] = [] {
        didSet {
            if highlightedRanges != oldValue {
                highlightedRangesForLine.removeAll()
                highlightRectsForLine.removeAll()
                highlightedRangesForLine = createHighlightedRangesPerLine()
            }
        }
    }

    private let selectionRectService: SelectionRectService
    private let lineControllerStorage: LineControllerStorage
    private var highlightedRangesForLine: [DocumentLineNodeID: [HighlightedRange]] = [:]
    private var highlightRectsForLine: [DocumentLineNodeID: [HighlightRect]] = [:]

    init(lineManager: LineManager, lineControllerStorage: LineControllerStorage, selectionRectService: SelectionRectService) {
        self.lineManager = lineManager
        self.lineControllerStorage = lineControllerStorage
        self.selectionRectService = selectionRectService
    }

    func highlightRects(forLineWithID lineID: DocumentLineNodeID) -> [HighlightRect] {
        if let highlightRects = highlightRectsForLine[lineID] {
            return highlightRects
        } else if let highlightedRanges = highlightedRangesForLine[lineID] {
            let highlightRects = highlightedRanges.flatMap { highlightedRange in
                let selectionRects = selectionRectService.selectionRects(in: highlightedRange.range)
                return selectionRects.map { selectionRect in
                    return HighlightRect(highlightedRange: highlightedRange, selectionRect: selectionRect)
                }
            }
            highlightRectsForLine[lineID] = highlightRects
            return highlightRects
        } else {
            return []
        }
    }

    func invalidateCachedRectanglesBelowLine(atIndex invalidatedLineIndex: Int) {
        var newHighlightRectsForLine = highlightRectsForLine
        for (lineID, _) in newHighlightRectsForLine {
            if let lineController = lineControllerStorage[lineID] {
                if lineController.line.index >= invalidatedLineIndex {
                    newHighlightRectsForLine.removeValue(forKey: lineID)
                }
            }
        }
        highlightRectsForLine = newHighlightRectsForLine
    }
}

private extension HighlightRectService {
    private func createHighlightedRangesPerLine() -> [DocumentLineNodeID: [HighlightedRange]] {
        var result: [DocumentLineNodeID: [HighlightedRange]] = [:]
        for highlightedRange in highlightedRanges where highlightedRange.range.length > 0 {
            let lines = lineManager.lines(in: highlightedRange.range)
            for line in lines {
                if let cappedRange = NSRange(globalRange: highlightedRange.range, cappedTo: line) {
                    let id = highlightedRange.id
                    let color = highlightedRange.color
                    let cornerRadius = highlightedRange.cornerRadius
                    let highlightedRange = HighlightedRange(id: id, range: cappedRange, color: color, cornerRadius: cornerRadius)
                    if let existingHighlightedRanges = result[line.id] {
                        result[line.id] = existingHighlightedRanges + [highlightedRange]
                    } else {
                        result[line.id] = [highlightedRange]
                    }
                }
            }
        }
        return result
    }
}
