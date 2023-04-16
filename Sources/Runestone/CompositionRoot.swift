import Combine
import Foundation

final class CompositionRoot {
    let textView = CurrentValueSubject<WeakBox<TextView>, Never>(WeakBox())
    let scrollView = CurrentValueSubject<WeakBox<MultiPlatformScrollView>, Never>(WeakBox())
    private(set) lazy var textViewDelegate = ErasedTextViewDelegate(textView: textView)
    #if os(iOS)
    private var textInputDelegate = TextInputDelegate_iOS()
    #else
    private var textInputDelegate = TextInputDelegate_Mac()
    #endif

    let isFirstResponder = CurrentValueSubject<Bool, Never>(false)
    private(set) lazy var keyWindowObserver = KeyWindowObserver(referenceView: textView)
    private(set) lazy var textViewNeedsLayoutObserver = TextViewNeedsLayoutObserver(
        textView: textView,
        stringView: stringView,
        viewport: textContainer.viewport
    )
    #if os(iOS)
    var memoryWarningObserver: MemoryWarningObserver {
        MemoryWarningObserver(handlers: [
            LineControllerStorageLowMemoryHandler(
                lineControllerStorage: lineControllerStorage,
                lineFragmentLayouter: lineFragmentLayouter
            )
        ])
    }
    #endif

    let stringView = CurrentValueSubject<StringView, Never>(StringView())
    private(set) lazy var lineManager = CurrentValueSubject<LineManager, Never>(
        LineManager(stringView: stringView.value)
    )
    private(set) lazy var lineControllerStorage = LineControllerStorage(
        stringView: stringView,
        lineControllerFactory: lineControllerFactory
    )

    let selectedRange = CurrentValueSubject<NSRange, Never>(NSRange(location: 0, length: 0))
    let markedRange = CurrentValueSubject<NSRange?, Never>(nil)

    let textContainer = TextContainer()
    private(set) lazy var typesetSettings = TypesetSettings(font: themeSettings.font)
    private(set) lazy var invisibleCharacterSettings = InvisibleCharacterSettings(
        font: themeSettings.font,
        textColor: themeSettings.invisibleCharactersColor
    )
    let themeSettings = ThemeSettings()
    let insertionPointShape = CurrentValueSubject<InsertionPointShape, Never>(.verticalBar)

    let undoManager: UndoManager = CoalescingUndoManager()
    private(set) lazy var characterPairService = CharacterPairService(
        stringView: stringView,
        selectedRange: selectedRange,
        textEditor: textEditor,
        textViewDelegate: textViewDelegate
    )
    var indentationChecker: IndentationChecker {
        IndentationChecker(
            stringView: stringView,
            lineManager: lineManager,
            indentStrategy: typesetSettings.indentStrategy
        )
    }

    let languageMode = CurrentValueSubject<InternalLanguageMode, Never>(PlainTextInternalLanguageMode())
    var languageModeSetter: LanguageModeSetter {
        LanguageModeSetter(
            stringView: stringView,
            languageMode: languageMode,
            internalLanguageModeFactory: internalLanguageModeFactory
        )
    }

    var textSetter: TextSetter {
        TextSetter(
            textInputDelegate: textInputDelegate,
            stringView: stringView,
            lineManager: lineManager,
            selectedRange: selectedRange,
            languageMode: languageMode,
            lineControllerStorage: lineControllerStorage,
            undoManager: textEditingUndoManager
        )
    }
    var textViewStateSetter: TextViewStateSetter {
        TextViewStateSetter(
            textInputDelegate: textInputDelegate,
            stringView: stringView,
            lineManager: lineManager,
            selectedRange: selectedRange,
            languageMode: languageMode,
            lineControllerStorage: lineControllerStorage,
            undoManager: textEditingUndoManager,
            themeSettings: themeSettings,
            estimatedLineHeight: estimatedLineHeight,
            internalLanguageModeFactory: internalLanguageModeFactory
        )
    }

    private(set) lazy var editorState = EditorState(textView: textView, textViewDelegate: textViewDelegate)
    private let textEditState = TextEditState()
    private(set) lazy var textReplacer = TextReplacer(
        stringView: stringView,
        selectedRange: selectedRange,
        markedRange: markedRange,
        textViewDelegate: textViewDelegate,
        textEditor: textEditor,
        characterPairService: characterPairService,
        replacementTextPreparator: replacementTextPreparator,
        undoManager: textEditingUndoManager
    )
    private(set) lazy var textInserter = TextInserter(
        lineManager: lineManager,
        selectedRange: selectedRange,
        markedRange: markedRange,
        languageMode: languageMode,
        lineEndings: typesetSettings.lineEndings,
        indentStrategy: typesetSettings.indentStrategy,
        textReplacer: textReplacer
    )
    private(set) lazy var textDeleter = TextDeleter(
        stringView: stringView,
        selectedRange: selectedRange,
        markedRange: markedRange,
        stringTokenizer: stringTokenizer,
        textEditState: textEditState,
        textViewDelegate: textViewDelegate,
        textEditor: textEditor,
        undoManager: textEditingUndoManager,
        textInputDelegate: textInputDelegate,
        deletionRangeFactory: textDeletionRangeFactory,
        viewportScroller: automaticViewportScroller
    )
    var textShifter: TextShifter {
        TextShifter(
            stringView: stringView,
            lineManager: lineManager,
            indentStrategy: typesetSettings.indentStrategy,
            selectedRange: selectedRange,
            textEditor: textEditor
        )
    }
    private var textDeletionRangeFactory: TextDeletionRangeFactory {
        TextDeletionRangeFactory(
            stringView: stringView,
            indentRangeFactory: deleteIndentRangeFactory,
            characterPairRangeFactory: deleteCharacterPairRangeFactory
        )
    }
    private var deleteIndentRangeFactory: DeleteIndentRangeFactory {
        DeleteIndentRangeFactory(
            stringView: stringView,
            lineManager: lineManager,
            indentStrategy: typesetSettings.indentStrategy
        )
    }
    private var deleteCharacterPairRangeFactory: DeleteCharacterPairRangeFactory {
        DeleteCharacterPairRangeFactory(stringView: stringView, characterPairService: characterPairService)
    }

    private(set) lazy var contentSizeService = ContentSizeService(
        scrollView: scrollView,
        totalLineHeightTracker: totalLineHeightTracker,
        widestLineTracker: widestLineTracker,
        viewport: textContainer.viewport,
        textContainerInset: textContainer.inset,
        isLineWrappingEnabled: typesetSettings.isLineWrappingEnabled,
        maximumLineBreakSymbolWidth: invisibleCharacterSettings.maximumLineBreakSymbolWidth,
        estimatedCharacterWidth: estimatedCharacterWidth,
        insertionPointShape: insertionPointShape
    )
    private(set) lazy var estimatedLineHeight = EstimatedLineHeight(
        font: themeSettings.font.eraseToAnyPublisher(),
        lineHeightMultiplier: typesetSettings.lineHeightMultiplier.eraseToAnyPublisher()
    )
    private(set) lazy var estimatedCharacterWidth = EstimatedCharacterWidth(font: themeSettings.font)
    let widestLineTracker = WidestLineTracker()
    private lazy var totalLineHeightTracker = TotalLineHeightTracker(lineManager: lineManager)
    private(set) lazy var contentArea = ContentArea(
        viewport: textContainer.viewport,
        contentSize: contentSizeService.contentSize,
        textContainerInset: textContainer.inset
    )

    var locationNavigator: LocationNavigator {
        LocationNavigator(
            selectedRange: selectedRange,
            stringTokenizer: stringTokenizer,
            characterNavigationLocationService: characterNavigationLocationFactory,
            wordNavigationLocationService: wordNavigationLocationFactory,
            lineNavigationLocationFactory: lineNavigationLocationFactory
        )
    }
    var locationRaycaster: LocationRaycaster {
        LocationRaycaster(
            stringView: stringView,
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage,
            textContainerInset: textContainer.inset
        )
    }
    var selectionNavigator: SelectionNavigator {
        SelectionNavigator(
            stringView: stringView,
            lineManager: lineManager,
            selectedRange: selectedRange,
            lineControllerStorage: lineControllerStorage,
            stringTokenizer: stringTokenizer,
            characterNavigationLocationFactory: characterNavigationLocationFactory,
            wordNavigationLocationFactory: wordNavigationLocationFactory,
            lineNavigationLocationFactory: lineNavigationLocationFactory
        )
    }
    private(set) lazy var lineMover = LineMover(
        stringView: stringView,
        lineManager: lineManager,
        selectedRange: selectedRange,
        lineEndings: typesetSettings.lineEndings,
        textEditor: textEditor,
        undoManager: undoManager
    )
    private(set) lazy var goToLineNavigator = GoToLineNavigator(
        textView: textView,
        lineManager: lineManager,
        selectedRange: selectedRange,
        viewportScroller: viewportScroller
    )
    var syntaxNodeRaycaster: SyntaxNodeRaycaster {
        SyntaxNodeRaycaster(lineManager: lineManager, languageMode: languageMode)
    }
    var textLocationConverter: TextLocationConverter {
        TextLocationConverter(lineManager: lineManager)
    }

    var insertionPointLayouter: InsertionPointLayouter {
        InsertionPointLayouter(
            renderer: insertionPointRenderer,
            frame: insertionPointFramePublisherFactory.makeFramePublisher(),
            containerView: textView,
            selectedRange: selectedRange.eraseToAnyPublisher(),
            showInsertionPoint: showInsertionPoint
        )
    }
    private var insertionPointRenderer: InsertionPointRenderer {
        InsertionPointRenderer(
            backgroundRenderer: insertionPointBackgroundRenderer,
            foregroundRenderer: insertionPointForegoundRenderer
        )
    }
    private(set) lazy var insertionPointBackgroundRenderer = InsertionPointBackgroundRenderer()
    private(set) lazy var insertionPointForegoundRenderer = InsertionPointForegroundRenderer(
        lineManager: lineManager,
        lineControllerStorage: lineControllerStorage,
        selectedRange: selectedRange,
        insertionPointShape: insertionPointShape,
        invisibleCharacterRenderer: invisibleCharacterRenderer
    )
    private var invisibleCharacterRenderer: InvisibleCharacterRenderer {
        InvisibleCharacterRenderer(
            stringView: stringView,
            invisibleCharacterSettings: invisibleCharacterSettings
        )
    }

    private(set) lazy var lineFragmentLayouter = LineFragmentLayouter(
        scrollView: scrollView,
        stringView: stringView,
        lineManager: lineManager,
        lineControllerStorage: lineControllerStorage,
        widestLineTracker: widestLineTracker,
        totalLineHeightTracker: totalLineHeightTracker,
        textContainer: textContainer,
        isLineWrappingEnabled: typesetSettings.isLineWrappingEnabled,
        maximumLineBreakSymbolWidth: invisibleCharacterSettings.maximumLineBreakSymbolWidth,
        contentSize: contentSizeService.contentSize,
        containerView: textView
    )
    private var insertionPointFramePublisherFactory: InsertionPointFramePublisherFactory {
        InsertionPointFramePublisherFactory(
            insertionPointFrameFactory: insertionPointFrameFactory,
            selectedRange: selectedRange.eraseToAnyPublisher(),
            insertionPointShape: insertionPointShape.eraseToAnyPublisher(),
            contentArea: contentArea.rawValue.eraseToAnyPublisher(),
            estimatedLineHeight: estimatedLineHeight,
            estimatedCharacterWidth: estimatedCharacterWidth.rawValue.eraseToAnyPublisher(),
            kern: typesetSettings.kern.eraseToAnyPublisher()
        )
    }
    private var insertionPointFrameFactory: InsertionPointFrameFactory {
        InsertionPointFrameFactory(
            stringView: stringView,
            lineManager: lineManager,
            characterBoundsProvider: characterBoundsProvider,
            lineControllerStorage: lineControllerStorage,
            shape: insertionPointShape,
            contentArea: contentArea.rawValue,
            estimatedLineHeight: estimatedLineHeight,
            estimatedCharacterWidth: estimatedCharacterWidth.rawValue
        )
    }
    private var characterBoundsProvider: CharacterBoundsProvider {
        CharacterBoundsProvider(
            stringView: stringView,
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage,
            contentArea: contentArea
        )
    }
    #if os(macOS)
    var textSelectionLayouter: TextSelectionLayouter {
        TextSelectionLayouter(
            textSelectionRectFactory: textSelectionRectFactory,
            containerView: textView,
            viewport: textContainer.viewport,
            selectedRange: selectedRange
        )
    }
    #endif
    var lineSelectionLayouter: LineSelectionLayouter {
        LineSelectionLayouter(
            selectedRange: selectedRange,
            lineManager: lineManager,
            viewport: textContainer.viewport,
            textContainerInset: textContainer.inset,
            lineHeightMultiplier: typesetSettings.lineHeightMultiplier,
            backgroundColor: themeSettings.selectedLineBackgroundColor,
            containerView: textView
        )
    }
    var pageGuideLayouter: PageGuideLayouter {
        PageGuideLayouter(
            font: themeSettings.font,
            kern: typesetSettings.kern,
            backgroundColor: themeSettings.pageGuideBackgroundColor,
            hairlineColor: themeSettings.pageGuideHairlineColor,
            hairlineWidth: themeSettings.pageGuideHairlineWidth,
            containerView: textView
        )
    }

    private(set) lazy var viewportScroller = ViewportScroller(
        scrollView: scrollView,
        textContainerInset: textContainer.inset,
        insertionPointFrameFactory: insertionPointFrameFactory,
        lineHeightMultiplier: typesetSettings.lineHeightMultiplier,
        lineFragmentLayouter: lineFragmentLayouter,
        contentSizeService: contentSizeService
    )
    private(set) lazy var automaticViewportScroller = AutomaticViewportScroller(
        selectedRange: selectedRange,
        viewportScroller: viewportScroller
    )

    var searchService: SearchService {
        SearchService(stringView: stringView, textLocationConverter: textLocationConverter)
    }
    var batchReplacer: BatchReplacer {
        BatchReplacer(
            stringView: stringView,
            lineManager: lineManager,
            selectedRange: selectedRange,
            textSetter: textSetter
        )
    }

    private(set) lazy var highlightedRangeFragmentStore = HighlightedRangeFragmentStore(
        stringView: stringView,
        lineManager: lineManager
    )
    private(set) lazy var highlightedRangeNavigator = HighlightedRangeNavigator(
        textView: textView,
        textViewDelegate: textViewDelegate,
        selectedRange: selectedRange,
        highlightedRanges: highlightedRangeFragmentStore.highlightedRanges,
        viewportScroller: viewportScroller,
        editMenuPresenter: editMenuPresenter
    )

    private lazy var defaultStringAttributes = DefaultStringAttributes(
        font: themeSettings.font,
        textColor: themeSettings.textColor,
        kern: typesetSettings.kern
    )
}

private extension CompositionRoot {
    private var showInsertionPoint: AnyPublisher<Bool, Never> {
        Publishers.CombineLatest3(
            keyWindowObserver.isKeyWindow,
            isFirstResponder,
            selectedRange
        ).map { isKeyWindow, isFirstResponder, selectedRange in
            isKeyWindow && isFirstResponder && selectedRange.length == 0
        }.eraseToAnyPublisher()
    }

    private var textEditingUndoManager: TextEditingUndoManager {
        TextEditingUndoManager(
            stringView: stringView,
            selectedRange: selectedRange,
            undoManager: undoManager,
            textEditor: textEditor
        )
    }

    private var textEditor: TextEditor {
        TextEditor(
            textViewDelegate: textViewDelegate,
            stringView: stringView,
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage,
            languageMode: languageMode,
            undoManager: undoManager,
            viewport: textContainer.viewport,
            lineFragmentLayouter: lineFragmentLayouter
        )
    }

    private var replacementTextPreparator: ReplacementTextPreparator {
        ReplacementTextPreparator(lineEndings: typesetSettings.lineEndings)
    }

    private var editMenuPresenter: EditMenuPresenter {
        #if os(iOS)
        #else
        EditMenuPresenter_Mac()
        #endif
    }

    private var stringTokenizer: StringTokenizer {
        StringTokenizer(
            stringView: stringView,
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage
        )
    }

    private var textSelectionRectFactory: TextSelectionRectFactory {
        TextSelectionRectFactory(
            characterBoundsProvider: characterBoundsProvider,
            lineManager: lineManager,
            contentArea: contentArea.rawValue,
            lineHeightMultiplier: typesetSettings.lineHeightMultiplier
        )
    }

    private var lineControllerFactory: LineControllerFactory {
        LineControllerFactory(
            stringView: stringView,
            estimatedLineHeight: estimatedLineHeight,
            defaultStringAttributes: defaultStringAttributes,
            typesetSettings: typesetSettings,
            lineFragmentControllerFactory: lineFragmentControllerFactory,
            syntaxHighlighterFactory: syntaxHighlighterFactory
        )
    }

    private var lineFragmentControllerFactory: LineFragmentControllerFactory {
        LineFragmentControllerFactory(
            selectedRange: selectedRange,
            rendererFactory: lineFragmentRendererFactory
        )
    }

    private var lineFragmentRendererFactory: LineFragmentRendererFactory {
        LineFragmentRendererFactory(
            stringView: stringView,
            invisibleCharacterSettings: invisibleCharacterSettings,
            invisibleCharacterRenderer: invisibleCharacterRenderer
        )
    }

    private var syntaxHighlighterFactory: SyntaxHighlighterFactory {
        SyntaxHighlighterFactory(theme: themeSettings.theme, languageMode: languageMode)
    }

    private var internalLanguageModeFactory: InternalLanguageModeFactory {
        InternalLanguageModeFactory(stringView: stringView, lineManager: lineManager)
    }

    private var characterNavigationLocationFactory: CharacterNavigationLocationFactory {
        CharacterNavigationLocationFactory(stringView: stringView)
    }

    private var wordNavigationLocationFactory: WordNavigationLocationFactory {
        WordNavigationLocationFactory(stringTokenizer: stringTokenizer)
    }

    private var lineNavigationLocationFactory: LineNavigationLocationFactory {
        #if os(macOS)
        StatefulLineNavigationLocationFactory(lineNavigationLocationFactory: statelessLineNavigationLocationFactory)
        #else
        statelessLineNavigationLocationFactory
        #endif
    }

    private var statelessLineNavigationLocationFactory: StatelessLineNavigationLocationFactory {
        StatelessLineNavigationLocationFactory(
            stringView: stringView,
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage
        )
    }
}
