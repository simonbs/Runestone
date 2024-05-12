import Combine
import Foundation

final class LineMover<StringViewType: StringView, LineManagerType: LineManaging> {
    private struct MoveLinesOperation {
        let removeRange: NSRange
        let replacementRange: NSRange
        let replacementString: String
        let selectedRange: NSRange
    }

    private let stringView: StringViewType
    private let lineManager: LineManagerType
    private let selectedRange: CurrentValueSubject<NSRange, Never>
    private let lineEndings: CurrentValueSubject<LineEnding, Never>
    private let textReplacer: TextReplacing
    private let undoManager: UndoManager

    init(
        stringView: StringViewType,
        lineManager: LineManagerType,
        selectedRange: CurrentValueSubject<NSRange, Never>,
        lineEndings: CurrentValueSubject<LineEnding, Never>,
        textReplacer: TextReplacing,
        undoManager: UndoManager
    ) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.selectedRange = selectedRange
        self.lineEndings = lineEndings
        self.textReplacer = textReplacer
        self.undoManager = undoManager
    }

    func moveSelectedLinesUp() {
        moveSelectedLine(byOffset: -1, undoActionName: L10n.Undo.ActionName.moveLinesUp)
    }

    func moveSelectedLinesDown() {
        moveSelectedLine(byOffset: 1, undoActionName: L10n.Undo.ActionName.moveLinesDown)
    }
}

private extension LineMover {
    private func moveSelectedLine(byOffset lineOffset: Int, undoActionName: String) {
        guard let operation = operationForMovingLines(in: selectedRange.value, byOffset: lineOffset) else {
            return
        }
        undoManager.endUndoGrouping()
        undoManager.beginUndoGrouping()
        textReplacer.replaceText(in: operation.removeRange, with: "")
        textReplacer.replaceText(in: operation.replacementRange, with: operation.replacementString)
//        #if os(iOS)
//        textView.notifyInputDelegateAboutSelectionChangeInLayoutSubviews = true
//        #endif
        selectedRange.value = operation.selectedRange
        undoManager.endUndoGrouping()
    }

    private func operationForMovingLines(in selectedRange: NSRange, byOffset lineOffset: Int) -> MoveLinesOperation? {
        // This implementation of moving lines is naive, as it first removes the selected lines and
        // then inserts the text at the target line. That requires two parses of the syntax tree
        // and two operations on our line manager. Ideally we would do this in one operation.
        let isMovingDown = lineOffset > 0
        let selectedLines = lineManager.lines(in: selectedRange)
        guard !selectedLines.isEmpty else {
            return nil
        }
        let firstLine = selectedLines[0]
        let lastLine = selectedLines[selectedLines.count - 1]
        let firstLineIndex = firstLine.index
        var targetLineIndex = firstLineIndex + lineOffset
        if isMovingDown {
            targetLineIndex += selectedLines.count - 1
        }
        guard targetLineIndex >= 0 && targetLineIndex < lineManager.lineCount else {
            return nil
        }
        // Find the line to move the selected text to.
        let targetLine = lineManager[targetLineIndex]
        // Find the range of text to remove. That's the range encapsulating selected lines.
        let removeLocation = firstLine.location
        let removeLength = lastLine.location + lastLine.totalLength - removeLocation
        // Find the location to insert the text at.
        var insertLocation = targetLine.location
        if isMovingDown {
            insertLocation += targetLine.totalLength - removeLength
        }
        // Update the selected range to match the old one but at the new lines.
        var locationOffset = insertLocation - removeLocation
        // Perform the remove and insert operations.
        var removeRange = NSRange(location: removeLocation, length: removeLength)
        let insertRange = NSRange(location: insertLocation, length: 0)
        var text = stringView.substring(in: removeRange) ?? ""
        if isMovingDown && targetLine.delimiterLength == 0 {
            if lastLine.delimiterLength > 0 {
                // We're moving to a line with no line break so we'll remove the last line break
                // from the text we're moving. This behavior matches the one of Nova.
                text.removeLast(lastLine.delimiterLength)
            }
            // Since the line we're moving to has no line break, we should add one in the beginning of the text.
            text = lineEndings.value.symbol + text
            locationOffset += lineEndings.value.symbol.utf16.count
        } else if !isMovingDown && lastLine.delimiterLength == 0 {
            // The last line we're moving has no line break, so we'll add one.
            text += lineEndings.value.symbol
            // Adjust the removal range to remove the line break of the line we're moving to.
            if targetLine.delimiterLength > 0 {
                removeRange.location -= targetLine.delimiterLength
                removeRange.length += targetLine.delimiterLength
            }
        }
        let newSelectedRange = NSRange(location: selectedRange.location + locationOffset, length: selectedRange.length)
        return MoveLinesOperation(
            removeRange: removeRange,
            replacementRange: insertRange,
            replacementString: text,
            selectedRange: newSelectedRange
        )
    }
}
