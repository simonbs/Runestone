//import Combine
//import Foundation
//
//final class TextViewStateSetter<LineManagerType: LineManaging> {
//    private let textInputDelegate: TextInputDelegate
//    private let stringView: any StringView
//    private let lineManager: LineManagerType
//    private let selectedRange: CurrentValueSubject<NSRange, Never>
//    private let languageMode: CurrentValueSubject<any InternalLanguageMode, Never>
//    private let lineControllerStore: LineControllerStoring
//    private let undoManager: TextEditingUndoManager
//    private let themeSettings: ThemeSettings
//    private let estimatedLineHeight: EstimatedLineHeight
//    private let internalLanguageModeFactory: InternalLanguageModeFactory
//
//    init(
//        textInputDelegate: TextInputDelegate,
//        stringView: any StringView,
//        lineManager: LineManagerType,
//        selectedRange: CurrentValueSubject<NSRange, Never>,
//        languageMode: CurrentValueSubject<any InternalLanguageMode, Never>,
//        lineControllerStore: LineControllerStoring,
//        undoManager: TextEditingUndoManager,
//        themeSettings: ThemeSettings,
//        estimatedLineHeight: EstimatedLineHeight,
//        internalLanguageModeFactory: InternalLanguageModeFactory
//    ) {
//        self.textInputDelegate = textInputDelegate
//        self.stringView = stringView
//        self.lineManager = lineManager
//        self.selectedRange = selectedRange
//        self.languageMode = languageMode
//        self.lineControllerStore = lineControllerStore
//        self.undoManager = undoManager
//        self.themeSettings = themeSettings
//        self.estimatedLineHeight = estimatedLineHeight
//        self.internalLanguageModeFactory = internalLanguageModeFactory
//    }
//
//    func setState(_ state: TextViewState, addUndoAction: Bool = false) {
//        let oldSelectedRange = selectedRange.value
//        let oldText = stringView.string
//        let newText = state.stringView.string
//        updateUndoManager(replacing: oldText, with: newText, addUndoAction: addUndoAction)
////        state.lineManager.estimatedLineHeight = estimatedLineHeight.rawValue.value
//        stringView = state.stringView
////        lineManager = state.lineManager
//        themeSettings.theme.value = state.theme
//        languageMode.value = internalLanguageModeFactory.internalLanguageMode(from: state.languageModeState)
//        lineControllerStore.removeAllLineControllers()
////        contentSizeService.reset()
////        gutterWidthService.invalidateLineNumberWidth()
////        highlightedRangeService.invalidateHighlightedRangeFragments()
//        textInputDelegate.selectionWillChange()
//        selectedRange.value = oldSelectedRange.capped(to: stringView.length)
//        textInputDelegate.selectionDidChange()
//    }
//}
//
//private extension TextViewStateSetter {
//    private func updateUndoManager(replacing oldText: NSString, with newText: NSString, addUndoAction: Bool) {
//        guard addUndoAction else {
//            undoManager.removeAllActions()
//            return
//        }
//        guard oldText != newText else {
//            return
//        }
//        let newRange = NSRange(location: 0, length: newText.length)
//        undoManager.endUndoGrouping()
//        undoManager.beginUndoGrouping()
//        undoManager.registerUndoOperation(
//            named: L10n.Undo.ActionName.typing,
//            forReplacingTextIn: newRange
//        )
//        undoManager.endUndoGrouping()
//    }
//}
