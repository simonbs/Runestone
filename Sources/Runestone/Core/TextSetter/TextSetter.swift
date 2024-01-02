import Foundation

final class TextSetter<
    LineManagerType: LineManaging,
    InternalLanguageModeType: InternalLanguageMode
>: TextSetting {
    typealias State = SelectedRangeWritable

    private let state: State
    private let textInputDelegate: TextInputDelegate
    private let stringView: StringView
    private let lineManager: LineManagerType
    private let languageMode: InternalLanguageModeType
    private let undoManager: TextEditingUndoManager

    init(
        state: State,
        textInputDelegate: TextInputDelegate,
        stringView: StringView,
        lineManager: LineManagerType,
        languageMode: InternalLanguageModeType,
        undoManager: TextEditingUndoManager
    ) {
        self.state = state
        self.textInputDelegate = textInputDelegate
        self.stringView = stringView
        self.lineManager = lineManager
        self.languageMode = languageMode
        self.undoManager = undoManager
    }

    func setText(_ newText: NSString, preservingUndoStack: Bool = false) {
        guard newText != stringView.string else {
            return
        }
        let oldSelectedRange = state.selectedRange
        stringView.string = newText
        languageMode.parse(newText)
//        lineControllerStore.removeAllLineControllers()
//        lineManager.rebuild()
        textInputDelegate.selectionWillChange()
        state.selectedRange = oldSelectedRange.capped(to: stringView.length)
        textInputDelegate.selectionDidChange()
//        contentSizeService.reset()
//        gutterWidthService.invalidateLineNumberWidth()
//        highlightedRangeService.invalidateHighlightedRangeFragments()
//        invalidateLines()
//        lineFragmentLayouter.setNeedsLayout()
//        lineFragmentLayouter.layoutIfNeeded()
        if !preservingUndoStack {
            undoManager.removeAllActions()
        }
    }
}
