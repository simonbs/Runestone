import Combine
import Foundation

final class CompositionRoot {
    private(set) lazy var textViewDelegate = ErasedTextViewDelegate(textView: textView)
    let scrollView = CurrentValueSubject<WeakBox<MultiPlatformScrollView>, Never>(WeakBox())
    private(set) lazy var keyWindowObserver = KeyWindowObserver(referenceView: textView)
    let isFirstResponder = CurrentValueSubject<Bool, Never>(false)
    private(set) lazy var editorState = EditorState(textView: textView, textViewDelegate: textViewDelegate)
    let selectedRange = CurrentValueSubject<NSRange, Never>(NSRange(location: 0, length: 0))
    let markedRange = CurrentValueSubject<NSRange?, Never>(nil)
    let stringView = CurrentValueSubject<StringView, Never>(StringView())
    let undoManager: UndoManager = CoalescingUndoManager()
    private(set) lazy var estimatedLineHeight = EstimatedLineHeight(
        font: themeSettings.font.eraseToAnyPublisher(),
        lineHeightMultiplier: typesetSettings.lineHeightMultiplier.eraseToAnyPublisher()
    )
    private(set) lazy var defaultStringAttributes = DefaultStringAttributes(
        font: themeSettings.font,
        textColor: themeSettings.textColor,
        kern: typesetSettings.kern
    )
    private(set) lazy var lineManager = CurrentValueSubject<LineManager, Never>(
        LineManager(stringView: stringView.value)
    )
    let textContainer = TextContainer()
    private(set) lazy var typesetSettings = TypesetSettings(font: themeSettings.font)
    private(set) lazy var invisibleCharacterSettings = InvisibleCharacterSettings(
        font: themeSettings.font,
        textColor: themeSettings.invisibleCharactersColor
    )
    let themeSettings = ThemeSettings()
    let languageMode = CurrentValueSubject<InternalLanguageMode, Never>(PlainTextInternalLanguageMode())
    private(set) lazy var lineControllerStorage = LineControllerStorage(
        stringView: stringView,
        lineControllerFactory: lineControllerFactory
    )
    let widestLineTracker = WidestLineTracker()
    private(set) lazy var contentSizeService = ContentSizeService(
        scrollView: scrollView,
        totalLineHeightTracker: totalLineHeightTracker,
        widestLineTracker: widestLineTracker,
        viewport: textContainer.viewport,
        textContainerInset: textContainer.inset,
        isLineWrappingEnabled: typesetSettings.isLineWrappingEnabled,
        maximumLineBreakSymbolWidth: invisibleCharacterSettings.maximumLineBreakSymbolWidth
    )
    private(set) lazy var contentArea = ContentArea(
        viewport: textContainer.viewport,
        contentSize: contentSizeService.contentSize,
        textContainerInset: textContainer.inset
    )
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
    private var textEditState = TextEditState()

    #if os(iOS)
    private var textInputDelegate = TextInputDelegate_iOS()
    #else
    private var textInputDelegate = TextInputDelegate_Mac()
    #endif

    private unowned let textView: TextView
    private lazy var totalLineHeightTracker = TotalLineHeightTracker(lineManager: lineManager)

    private(set) lazy var caret = Caret(
        stringView: stringView,
        lineManager: lineManager,
        lineControllerStorage: lineControllerStorage,
        contentArea: contentArea.rawValue,
        location: selectedRange.map(\.location).eraseToAnyPublisher()
    )

    var caretLayouter: CaretLayouter {
        CaretLayouter(
            caret: caret,
            containerView: textView,
            selectedRange: selectedRange.eraseToAnyPublisher(),
            showCaret: showCaret
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
        contentSize: contentSizeService.contentSize,
        containerView: textView
    )

    var lineSelectionLayouter: LineSelectionLayouter {
        LineSelectionLayouter(
            caret: caret,
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

    var syntaxNodeRaycaster: SyntaxNodeRaycaster {
        SyntaxNodeRaycaster(lineManager: lineManager, languageMode: languageMode)
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

    private(set) lazy var characterPairService = CharacterPairService(
        stringView: stringView,
        selectedRange: selectedRange,
        textEditor: textEditor,
        textViewDelegate: textViewDelegate
    )

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

    private(set) lazy var viewportScroller = ViewportScroller(
        scrollView: scrollView,
        textContainerInset: textContainer.inset,
        caret: caret,
        estimatedLineHeight: estimatedLineHeight,
        lineFragmentLayouter: lineFragmentLayouter,
        contentSizeService: contentSizeService
    )

    private(set) lazy var automaticViewportScroller = AutomaticViewportScroller(
        selectedRange: selectedRange,
        viewportScroller: viewportScroller
    )

    init(textView: TextView) {
        self.textView = textView
    }
}

private extension CompositionRoot {
    private var textSelectionRectFactory: TextSelectionRectFactory {
        TextSelectionRectFactory(
            caret: caret,
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
            invisibleCharacterSettings: invisibleCharacterSettings,
            rendererFactory: rendererFactory,
            syntaxHighlighterFactory: syntaxHighlighterFactory
        )
    }

    private var rendererFactory: RendererFactory {
        RendererFactory(stringView: stringView, invisibleCharacterSettings: invisibleCharacterSettings)
    }

    private var syntaxHighlighterFactory: SyntaxHighlighterFactory {
        SyntaxHighlighterFactory(theme: themeSettings.theme, languageMode: languageMode)
    }

    private var showCaret: AnyPublisher<Bool, Never> {
        Publishers.CombineLatest3(
            keyWindowObserver.isKeyWindow,
            isFirstResponder,
            selectedRange
        ).map { isKeyWindow, isFirstResponder, selectedRange in
            isKeyWindow && isFirstResponder && selectedRange.length == 0
        }.eraseToAnyPublisher()
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

    private var textEditingUndoManager: TextEditingUndoManager {
        TextEditingUndoManager(
            stringView: stringView,
            selectedRange: selectedRange,
            undoManager: undoManager,
            textEditor: textEditor
        )
    }

    private var editMenuPresenter: EditMenuPresenter {
        #if os(iOS)
        #else
        EditMenuPresenter_Mac()
        #endif
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
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage
        )
    }

    private var stringTokenizer: StringTokenizer {
        StringTokenizer(
            stringView: stringView,
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage
        )
    }
}
