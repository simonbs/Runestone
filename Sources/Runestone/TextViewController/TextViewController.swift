// swiftlint:disable file_length
import Combine
import Foundation

// swiftlint:disable:next type_body_length
final class TextViewController {
    let textViewDelegate: ErasedTextViewDelegate
    let scrollView: CurrentValueSubject<WeakBox<MultiPlatformScrollView>, Never>
    let isFirstResponder: CurrentValueSubject<Bool, Never>
    let stringView: CurrentValueSubject<StringView, Never>
    let lineManager: CurrentValueSubject<LineManager, Never>
    let lineControllerStorage: LineControllerStorage
    let textContainer: TextContainer
    let typesetSettings: TypesetSettings
    let invisibleCharacterSettings: InvisibleCharacterSettings
    let themeSettings: ThemeSettings
    let selectedRange: CurrentValueSubject<NSRange, Never>
    let markedRange: CurrentValueSubject<NSRange?, Never>
    let languageMode: CurrentValueSubject<InternalLanguageMode, Never>
    let textSetter: TextSetter
    let textViewStateSetter: TextViewStateSetter
    let languageModeSetter: LanguageModeSetter
    let locationNavigator: LocationNavigator
    let locationRaycaster: LocationRaycaster
    let syntaxNodeRaycaster: SyntaxNodeRaycaster
    let textLocationConverter: TextLocationConverter

    let lineFragmentLayouter: LineFragmentLayouter
    let lineSelectionLayouter: LineSelectionLayouter
    let pageGuideLayouter: PageGuideLayouter

    let caret: Caret
    let contentSizeService: ContentSizeService
    let editorState: EditorState
    let textReplacer: TextReplacer
    let textInserter: TextInserter
    let textDeleter: TextDeleter
    let textShifter: TextShifter

    let viewportScroller: ViewportScroller
    let automaticViewportScroller: AutomaticViewportScroller

    let searchService: SearchService
    let batchReplacer: BatchReplacer

    let undoManager: UndoManager
    let characterPairService: CharacterPairService
    let indentationChecker: IndentationChecker
    let goToLineNavigator: GoToLineNavigator
    let lineMover: LineMover
    let highlightedRangeFragmentStore: HighlightedRangeFragmentStore
    let highlightedRangeNavigator: HighlightedRangeNavigator

    #if os(macOS)
    let textSelectionLayouter: TextSelectionLayouter
    let caretLayouter: CaretLayouter
    let selectionNavigator: SelectionNavigator
    #endif

    #if os(iOS)
    let memoryWarningObserver: MemoryWarningObserver
    #endif

    private let estimatedLineHeight: EstimatedLineHeight
    private let widestLineTracker: WidestLineTracker
    private let contentArea: ContentArea

    private let textViewNeedsLayoutObserver: TextViewNeedsLayoutObserver
    private let keyWindowObserver: KeyWindowObserver
    private var cancellables: Set<AnyCancellable> = []

    // swiftlint:disable:next function_body_length
    init(textView: TextView) {
        let compositionRoot = CompositionRoot(textView: textView)
        textViewDelegate = compositionRoot.textViewDelegate
        textViewNeedsLayoutObserver = compositionRoot.textViewNeedsLayoutObserver
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
        textSetter = compositionRoot.textSetter
        textViewStateSetter = compositionRoot.textViewStateSetter
        languageModeSetter = compositionRoot.languageModeSetter
        estimatedLineHeight = compositionRoot.estimatedLineHeight
        caret = compositionRoot.caret
        highlightedRangeFragmentStore = compositionRoot.highlightedRangeFragmentStore
        highlightedRangeNavigator = compositionRoot.highlightedRangeNavigator
        lineControllerStorage = compositionRoot.lineControllerStorage
//        gutterWidthService = GutterWidthService(lineManager: lineManager)
        widestLineTracker = compositionRoot.widestLineTracker
        contentSizeService = compositionRoot.contentSizeService
        locationNavigator = compositionRoot.locationNavigator
        locationRaycaster = compositionRoot.locationRaycaster
        syntaxNodeRaycaster = compositionRoot.syntaxNodeRaycaster
        textLocationConverter = compositionRoot.textLocationConverter
        lineFragmentLayouter = compositionRoot.lineFragmentLayouter
        lineSelectionLayouter = compositionRoot.lineSelectionLayouter
        pageGuideLayouter = compositionRoot.pageGuideLayouter
        textReplacer = compositionRoot.textReplacer
        textInserter = compositionRoot.textInserter
        textDeleter = compositionRoot.textDeleter
        textShifter = compositionRoot.textShifter
        characterPairService = compositionRoot.characterPairService
        indentationChecker = compositionRoot.indentationChecker
        goToLineNavigator = compositionRoot.goToLineNavigator
        lineMover = compositionRoot.lineMover
        viewportScroller = compositionRoot.viewportScroller
        automaticViewportScroller = compositionRoot.automaticViewportScroller
        searchService = compositionRoot.searchService
        batchReplacer = compositionRoot.batchReplacer
        #if os(macOS)
        selectionNavigator = compositionRoot.selectionNavigator
        textSelectionLayouter = compositionRoot.textSelectionLayouter
        caretLayouter = compositionRoot.caretLayouter
        #endif
//        gutterWidthService.gutterLeadingPadding = gutterLeadingPadding
//        gutterWidthService.gutterTrailingPadding = gutterTrailingPadding
//        setupContentSizeObserver()
//        setupGutterWidthObserver()
    }
}
