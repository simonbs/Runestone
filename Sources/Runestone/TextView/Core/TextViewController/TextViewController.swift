// swiftlint:disable file_length
import Combine
import Foundation

// swiftlint:disable:next type_body_length
final class TextViewController {
    let textViewDelegateBox = TextViewDelegateBox()
    let scrollView: CurrentValueSubject<ScrollViewBox, Never>
    let isFirstResponder: CurrentValueSubject<Bool, Never>
    let editorState: EditorState
    let selectedRange: CurrentValueSubject<NSRange, Never>
    let markedRange: CurrentValueSubject<NSRange?, Never>
    let stringView: CurrentValueSubject<StringView, Never>
    var text: String {
        get {
            stringView.value.string as String
        }
        set {
            let nsString = newValue as NSString
            if nsString != stringView.value.string {
                stringView.value.string = nsString
                languageMode.value.parse(nsString)
                lineControllerStorage.removeAllLineControllers()
                lineManager.value.rebuild()
//                if let oldSelectedRange = selectedRange {
//                    #if os(iOS)
//                    textView.inputDelegate?.selectionWillChange(textView)
//                    #endif
//                    selectedRange = oldSelectedRange.capped(to: stringView.value.string.length)
//                    #if os(iOS)
//                    textView.inputDelegate?.selectionDidChange(textView)
//                    #endif
//                }
//                contentSizeService.reset()
//                gutterWidthService.invalidateLineNumberWidth()
//                highlightedRangeService.invalidateHighlightedRangeFragments()
//                invalidateLines()
//                lineFragmentLayouter.setNeedsLayout()
//                lineFragmentLayouter.layoutIfNeeded()
                if !preserveUndoStackWhenSettingString {
                    undoManager.removeAllActions()
                }
            }
        }
    }

    var preserveUndoStackWhenSettingString = false

    private weak var textView: TextView?
    private let keyWindowObserver: KeyWindowObserver

    let lineManager: CurrentValueSubject<LineManager, Never>
    let textContainer: TextContainer
    let typesetSettings: TypesetSettings
    let invisibleCharacterSettings: InvisibleCharacterSettings
    let themeSettings: ThemeSettings
    private let estimatedLineHeight: EstimatedLineHeight
    private let widestLineTracker: WidestLineTracker
    let languageMode: CurrentValueSubject<InternalLanguageMode, Never>
    private let contentArea: ContentArea
    let contentSizeService: ContentSizeService
    let caret: Caret
    let lineControllerStorage: LineControllerStorage
    let navigationService: NavigationService
    let lineFragmentLayouter: LineFragmentLayouter
    let lineSelectionLayouter: LineSelectionLayouter
    let pageGuideLayouter: PageGuideLayouter
    let textReplacer: TextReplacer
    let textInserter: TextInserter
    let textDeleter: TextDeleter
    let characterPairService: CharacterPairService
    let lineMover: LineMover
    let viewportScroller: ViewportScroller
    let undoManager: UndoManager
    let highlightedRangeFragmentStore: HighlightedRangeFragmentStore
    let highlightedRangeNavigator: HighlightedRangeNavigator
    #if os(macOS)
    let textSelectionLayouter: TextSelectionLayouter
    let caretLayouter: CaretLayouter
    let selectionService: SelectionService
    #endif

    var isAutomaticScrollEnabled = true

    private var cancellables: Set<AnyCancellable> = []

    // swiftlint:disable:next function_body_length
    init(textView: TextView) {
        let compositionRoot = CompositionRoot(textView: textView)
        self.textView = textView
        editorState = compositionRoot.editorState
        scrollView = compositionRoot.scrollView
        keyWindowObserver = compositionRoot.keyWindowObserver
        isFirstResponder = compositionRoot.isFirstResponder
        selectedRange = compositionRoot.selectedRange
        markedRange = compositionRoot.markedRange
        textContainer = compositionRoot.textContainer
        typesetSettings = compositionRoot.typesetSettings
        invisibleCharacterSettings = compositionRoot.invisibleCharacterSettings
        themeSettings = compositionRoot.themeSettings
        contentArea = compositionRoot.contentArea
        stringView = compositionRoot.stringView
        undoManager = compositionRoot.undoManager
        lineManager = compositionRoot.lineManager
        languageMode = compositionRoot.languageMode
        estimatedLineHeight = compositionRoot.estimatedLineHeight
        caret = compositionRoot.caret
        highlightedRangeFragmentStore = compositionRoot.highlightedRangeFragmentStore
        highlightedRangeNavigator = compositionRoot.highlightedRangeNavigator
        lineControllerStorage = compositionRoot.lineControllerStorage
//        gutterWidthService = GutterWidthService(lineManager: lineManager)
        widestLineTracker = compositionRoot.widestLineTracker
        contentSizeService = compositionRoot.contentSizeService
        navigationService = compositionRoot.navigationService
        lineFragmentLayouter = compositionRoot.lineFragmentLayouter
        lineSelectionLayouter = compositionRoot.lineSelectionLayouter
        pageGuideLayouter = compositionRoot.pageGuideLayouter
        textReplacer = compositionRoot.textReplacer
        textInserter = compositionRoot.textInserter
        textDeleter = compositionRoot.textDeleter
        characterPairService = compositionRoot.characterPairService
        lineMover = compositionRoot.lineMover
        viewportScroller = compositionRoot.viewportScroller
        #if os(macOS)
        selectionService = compositionRoot.selectionService
        textSelectionLayouter = compositionRoot.textSelectionLayouter
        caretLayouter = compositionRoot.caretLayouter
        #endif
//        gutterWidthService.gutterLeadingPadding = gutterLeadingPadding
//        gutterWidthService.gutterTrailingPadding = gutterTrailingPadding
//        setupContentSizeObserver()
//        setupGutterWidthObserver()
        setupTextViewNeedsLayoutObserver()
        #if os(iOS)
        subscribeToMemoryWarningNotification()
        #endif
    }

    func setState(_ state: TextViewState, addUndoAction: Bool = false) {
        let oldText = stringView.value.string
        let newText = state.stringView.string
        state.lineManager.estimatedLineHeight = estimatedLineHeight.rawValue
        stringView.value = state.stringView
        lineManager.value = state.lineManager
        themeSettings.theme.value = state.theme
        languageMode.value = InternalLanguageModeFactory.internalLanguageMode(
            from: state.languageModeState,
            stringView: stringView,
            lineManager: lineManager
        )
        lineControllerStorage.removeAllLineControllers()
//        contentSizeService.reset()
//        gutterWidthService.invalidateLineNumberWidth()
//        highlightedRangeService.invalidateHighlightedRangeFragments()
//        if addUndoAction {
//            if newText != oldText {
//                let newRange = NSRange(location: 0, length: newText.length)
//                undoManager.endUndoGrouping()
//                undoManager.beginUndoGrouping()
//                addUndoOperation(replacing: newRange, withText: oldText as String)
//                undoManager.endUndoGrouping()
//            }
//        } else {
//            undoManager.removeAllActions()
//        }
        #if os(iOS)
        textView.inputDelegate?.selectionWillChange(textView)
        selectedRange.value = oldSelectedRange.capped(to: stringView.string.length)
        textView.inputDelegate?.selectionDidChange(textView)
        #endif
    }

    func setLanguageMode(_ languageMode: LanguageMode, completion: ((Bool) -> Void)? = nil) {
        self.languageMode.value = InternalLanguageModeFactory.internalLanguageMode(
            from: languageMode,
            stringView: stringView,
            lineManager: lineManager
        )
        self.languageMode.value.parse(stringView.value.string) { [weak self] finished in
            if let self = self, finished {
//                self.invalidateLines()
//                self.lineFragmentLayouter.setNeedsLayout()
//                self.lineFragmentLayouter.layoutIfNeeded()
            }
            completion?(finished)
        }
    }
}

private extension TextViewController {
    private func setupTextViewNeedsLayoutObserver() {
        Publishers.CombineLatest(
            stringView,
            textContainer.viewport.removeDuplicates()
        ).sink { [weak self] _ in
            self?.textView?.setNeedsLayout()
        }.store(in: &cancellables)
    }
}
