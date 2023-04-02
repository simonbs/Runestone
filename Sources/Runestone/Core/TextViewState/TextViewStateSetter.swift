import Combine
import Foundation

final class TextViewStateSetter {
    private let textInputDelegate: TextInputDelegate
    private let stringView: CurrentValueSubject<StringView, Never>
    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let selectedRange: CurrentValueSubject<NSRange, Never>
    private let languageMode: CurrentValueSubject<InternalLanguageMode, Never>
    private let lineControllerStorage: LineControllerStorage
    private let undoManager: TextEditingUndoManager
    private let themeSettings: ThemeSettings
    private let estimatedLineHeight: EstimatedLineHeight
    private let internalLanguageModeFactory: InternalLanguageModeFactory

    init(
        textInputDelegate: TextInputDelegate,
        stringView: CurrentValueSubject<StringView, Never>,
        lineManager: CurrentValueSubject<LineManager, Never>,
        selectedRange: CurrentValueSubject<NSRange, Never>,
        languageMode: CurrentValueSubject<InternalLanguageMode, Never>,
        lineControllerStorage: LineControllerStorage,
        undoManager: TextEditingUndoManager,
        themeSettings: ThemeSettings,
        estimatedLineHeight: EstimatedLineHeight,
        internalLanguageModeFactory: InternalLanguageModeFactory
    ) {
        self.textInputDelegate = textInputDelegate
        self.stringView = stringView
        self.lineManager = lineManager
        self.selectedRange = selectedRange
        self.languageMode = languageMode
        self.lineControllerStorage = lineControllerStorage
        self.undoManager = undoManager
        self.themeSettings = themeSettings
        self.estimatedLineHeight = estimatedLineHeight
        self.internalLanguageModeFactory = internalLanguageModeFactory
    }

    func setState(_ state: TextViewState, addUndoAction: Bool = false) {
        let oldSelectedRange = selectedRange.value
        let oldText = stringView.value.string
        let newText = state.stringView.string
        updateUndoManager(replacing: oldText, with: newText, addUndoAction: addUndoAction)
        state.lineManager.estimatedLineHeight = estimatedLineHeight.value
        stringView.value = state.stringView
        lineManager.value = state.lineManager
        themeSettings.theme.value = state.theme
        languageMode.value = internalLanguageModeFactory.internalLanguageMode(from: state.languageModeState)
        lineControllerStorage.removeAllLineControllers()
//        contentSizeService.reset()
//        gutterWidthService.invalidateLineNumberWidth()
//        highlightedRangeService.invalidateHighlightedRangeFragments()
        textInputDelegate.selectionWillChange()
        selectedRange.value = oldSelectedRange.capped(to: stringView.value.string.length)
        textInputDelegate.selectionDidChange()
    }
}

private extension TextViewStateSetter {
    private func updateUndoManager(replacing oldText: NSString, with newText: NSString, addUndoAction: Bool) {
        guard addUndoAction else {
            undoManager.removeAllActions()
            return
        }
        guard oldText != newText else {
            return
        }
        let newRange = NSRange(location: 0, length: newText.length)
        undoManager.endUndoGrouping()
        undoManager.beginUndoGrouping()
        undoManager.registerUndoOperation(
            named: L10n.Undo.ActionName.typing,
            forReplacingTextIn: newRange,
            selectedRangeAfterUndo: newRange
        )
        undoManager.endUndoGrouping()
    }
}
