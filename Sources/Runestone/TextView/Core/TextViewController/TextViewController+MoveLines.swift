import Foundation

extension TextViewController {
    func moveSelectedLinesUp() {
        moveSelectedLine(byOffset: -1, undoActionName: L10n.Undo.ActionName.moveLinesUp)
    }

    func moveSelectedLinesDown() {
        moveSelectedLine(byOffset: 1, undoActionName: L10n.Undo.ActionName.moveLinesDown)
    }
}

private extension TextViewController {
    private func moveSelectedLine(byOffset lineOffset: Int, undoActionName: String) {
        let moveLinesService = MoveLinesService(stringView: stringView, lineManager: lineManager, lineEndingSymbol: lineEndings.symbol)
        guard let operation = moveLinesService.operationForMovingLines(in: selectedRange.value, byOffset: lineOffset) else {
            return
        }
        timedUndoManager.endUndoGrouping()
        timedUndoManager.beginUndoGrouping()
        replaceText(in: operation.removeRange, with: "", undoActionName: undoActionName)
        replaceText(in: operation.replacementRange, with: operation.replacementString, undoActionName: undoActionName)
        #if os(iOS)
        textView.notifyInputDelegateAboutSelectionChangeInLayoutSubviews = true
        #endif
        selectedRange.value = operation.selectedRange
        timedUndoManager.endUndoGrouping()
    }
}
