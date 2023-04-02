import Combine
import Foundation

final class TextSetter {
    private let textInputDelegate: TextInputDelegate
    private let stringView: CurrentValueSubject<StringView, Never>
    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let selectedRange: CurrentValueSubject<NSRange, Never>
    private let languageMode: CurrentValueSubject<InternalLanguageMode, Never>
    private let lineControllerStorage: LineControllerStorage
    private let undoManager: TextEditingUndoManager

    init(
        textInputDelegate: TextInputDelegate,
        stringView: CurrentValueSubject<StringView, Never>,
        lineManager: CurrentValueSubject<LineManager, Never>,
        selectedRange: CurrentValueSubject<NSRange, Never>,
        languageMode: CurrentValueSubject<InternalLanguageMode, Never>,
        lineControllerStorage: LineControllerStorage,
        undoManager: TextEditingUndoManager
    ) {
        self.textInputDelegate = textInputDelegate
        self.stringView = stringView
        self.lineManager = lineManager
        self.selectedRange = selectedRange
        self.languageMode = languageMode
        self.lineControllerStorage = lineControllerStorage
        self.undoManager = undoManager
    }

    func setText(_ newText: NSString, preservingUndoStack: Bool = false) {
        guard newText != stringView.value.string else {
            return
        }
        let oldSelectedRange = selectedRange.value
        stringView.value.string = newText
        languageMode.value.parse(newText)
        lineControllerStorage.removeAllLineControllers()
        lineManager.value.rebuild()
        textInputDelegate.selectionWillChange()
        selectedRange.value = oldSelectedRange.capped(to: stringView.value.string.length)
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
