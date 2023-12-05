import _RunestoneTreeSitter
import Foundation

final class TreeSitterIndentStrategyDetector<LineManagerType: LineManaging> {
    private let string: NSString
    private let lineManager: LineManagerType
    private let tree: TreeSitterTree

    init(string: NSString, lineManager: LineManagerType, tree: TreeSitterTree) {
        self.string = string
        self.lineManager = lineManager
        self.tree = tree
    }

    func detect() -> DetectedIndentStrategy {
        var shouldScan = true
        let iterator = lineManager.makeLineIterator()
        var lineCountBeginningWithTab = 0
        var lineCountBeginningWithSpace = 0
        var scannedLineCount = 0
        var scannedLineWithContentCount = 0
        let lineCount = lineManager.lineCount
        var lowestSpaceCount = Int.max
        var detectedStrategy: DetectedIndentStrategy = .unknown
        while let line = iterator.next(), shouldScan {
            scannedLineCount += 1
            let point = TreeSitterTextPoint(row: UInt32(line.index), column: 0)
            let node = tree.rootNode.descendantForRange(from: point, to: point)
            if node.type == "comment" {
                continue
            }
            if line.length <= 0 {
                continue
            }
            scannedLineWithContentCount += 1
            let lineLocation = line.location
            let range = NSRange(location: lineLocation, length: 1)
            let character = string.substring(with: range)
            if character == Symbol.tab {
                lineCountBeginningWithTab += 1
            } else if character == Symbol.space {
                let spaceCount = numberOfSpacesAtBeginning(
                    of: line,
                    lineLocation: lineLocation,
                    lowestSpaceCount: lowestSpaceCount
                )
                if spaceCount > 1 {
                    lowestSpaceCount = min(spaceCount, lowestSpaceCount)
                    lineCountBeginningWithSpace += 1
                }
            }
            // If we have scanned at least 20 lines that aren't either empty or a comment or we have seen 100 lines in total,
            // and we have found at least one line that begins with a tab or a space, then we base our suggested strategy on that.
            let hasScannedEnoughLines = scannedLineCount >= min(lineCount, 100) || scannedLineWithContentCount >= min(20, lineCount)
            let canSuggestStrategy = lineCountBeginningWithTab != 0 || lineCountBeginningWithSpace != 0
            if hasScannedEnoughLines && canSuggestStrategy {
                shouldScan = false
                if lineCountBeginningWithTab > lineCountBeginningWithSpace {
                    detectedStrategy = .tab
                } else {
                    detectedStrategy = .space(length: lowestSpaceCount)
                }
            }
        }
        return detectedStrategy
    }
}

private extension TreeSitterIndentStrategyDetector {
    private func numberOfSpacesAtBeginning(
        of line: LineManagerType.LineType,
        lineLocation: Int,
        lowestSpaceCount: Int
    ) -> Int {
        var range = NSRange(location: lineLocation, length: 1)
        var character = string.substring(with: range)
        var spaceCount = 0
        let stringLength = string.length
        while spaceCount < line.totalLength
                && character == Symbol.space
                && spaceCount < lowestSpaceCount
                && range.location < stringLength - 1
        {
            spaceCount += 1
            range = NSRange(location: range.location + 1, length: 1)
            character = string.substring(with: range)
        }
        return spaceCount
    }
}
