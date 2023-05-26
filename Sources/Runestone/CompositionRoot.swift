import Combine
import Foundation
#if os(iOS)
import UIKit
#endif

final class CompositionRoot {
    // MARK: - Core
    let textView = CurrentValueSubject<WeakBox<TextView>, Never>(WeakBox())
    let scrollView = CurrentValueSubject<WeakBox<MultiPlatformScrollView>, Never>(WeakBox())
    private(set) lazy var textViewDelegate = ErasedTextViewDelegate(textView: textView)
    let isFirstResponder = CurrentValueSubject<Bool, Never>(false)
    let stringView = CurrentValueSubject<StringView, Never>(StringView())
    private(set) lazy var editorState = EditorState(textView: textView, textViewDelegate: textViewDelegate)
    let selectedRange = CurrentValueSubject<NSRange, Never>(NSRange(location: 0, length: 0))
    let markedRange = CurrentValueSubject<NSRange?, Never>(nil)
    let textContainer = TextContainer()
    private var stringTokenizer: StringTokenizer {
        StringTokenizer(
            stringView: stringView,
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage
        )
    }
    private(set) lazy var textViewNeedsLayoutObserver = TextViewNeedsLayoutObserver(
        textView: textView,
        stringView: stringView,
        viewport: textContainer.viewport
    )
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

    // MARK: - Appearance
    let themeSettings = ThemeSettings()
    let textViewBackgroundColor = CurrentValueSubject<MultiPlatformColor?, Never>(.textBackgroundColor)
    private(set) lazy var typesetSettings = TypesetSettings(font: themeSettings.font)

    // MARK: - Line Management
    private(set) lazy var lineManager = CurrentValueSubject<LineManager, Never>(
        LineManager(stringView: stringView.value)
    )
    private(set) lazy var lineControllerStorage = LineControllerStorage(
        stringView: stringView,
        lineControllerFactory: lineControllerFactory
    )
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

    // MARK: - Line Fragments
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
    private var lineFragmentControllerFactory: LineFragmentControllerFactory {
        LineFragmentControllerFactory(
            selectedRange: selectedRange,
            rendererFactory: lineFragmentRendererFactory
        )
    }
    private var lineFragmentRendererFactory: LineFragmentRendererFactory {
        LineFragmentRendererFactory(
            stringView: stringView,
            showInvisibleCharacters: invisibleCharacterSettings.showInvisibleCharacters,
            invisibleCharacterRenderer: invisibleCharacterRenderer
        )
    }
    private var defaultStringAttributes: DefaultStringAttributes {
        DefaultStringAttributes(
            font: themeSettings.font,
            textColor: themeSettings.textColor,
            kern: typesetSettings.kern
        )
    }

    // MARK: - Content Size
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
    private lazy var contentArea = ContentAreaPublisherFactory(
        viewport: textContainer.viewport,
        contentSize: contentSizeService.contentSize,
        textContainerInset: textContainer.inset
    ).makePublisher()
    private lazy var totalLineHeightTracker = TotalLineHeightTracker(lineManager: lineManager)

    // MARK: - Editing
    let undoManager: UndoManager = CoalescingUndoManager()
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
    var textReplacer: TextReplacer {
        TextReplacer(
            stringView: stringView,
            selectedRange: selectedRange,
            markedRange: markedRange,
            textViewDelegate: textViewDelegate,
            textEditState: textEditState,
            textEditor: textEditor,
            lineEndings: typesetSettings.lineEndings,
            characterPairService: characterPairService,
            replacementTextPreparator: replacementTextPreparator,
            undoManager: textEditingUndoManager
        )
    }
    var textInserter: TextInserter {
        TextInserter(
            lineManager: lineManager,
            selectedRange: selectedRange,
            markedRange: markedRange,
            languageMode: languageMode,
            lineEndings: typesetSettings.lineEndings,
            indentStrategy: typesetSettings.indentStrategy,
            textReplacer: textReplacer
        )
    }
    var textDeleter: TextDeleter {
        TextDeleter(
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
    }
    var textShifter: TextShifter {
        TextShifter(
            stringView: stringView,
            lineManager: lineManager,
            indentStrategy: typesetSettings.indentStrategy,
            selectedRange: selectedRange,
            textEditor: textEditor
        )
    }
    var lineMover: LineMover {
        LineMover(
            stringView: stringView,
            lineManager: lineManager,
            selectedRange: selectedRange,
            lineEndings: typesetSettings.lineEndings,
            textEditor: textEditor,
            undoManager: undoManager
        )
    }
    var characterPairService: CharacterPairService {
        // Was lazy var
        CharacterPairService(
            stringView: stringView,
            selectedRange: selectedRange,
            textEditor: textEditor,
            textViewDelegate: textViewDelegate
        )
    }
    private let textEditState = TextEditState()
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
        DeleteCharacterPairRangeFactory(
            stringView: stringView,
            characterPairService: characterPairService
        )
    }
    private var firstRectFactory: FirstRectFactory {
        FirstRectFactory(
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage,
            viewport: textContainer.viewport,
            gutterWidthService: gutterWidthService,
            estimatedLineHeight: estimatedLineHeight,
            textContainerInset: textContainer.inset
        )
    }

    // MARK: - Scrolling
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

    // MARK: - Navigation
    var textLocationConverter: TextLocationConverter {
        TextLocationConverter(lineManager: lineManager)
    }
    var locationRaycaster: LocationRaycaster {
        LocationRaycaster(
            stringView: stringView,
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage,
            textContainerInset: textContainer.inset
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
    var goToLineNavigator: GoToLineNavigator {
        GoToLineNavigator(
            textView: textView,
            lineManager: lineManager,
            selectedRange: selectedRange,
            viewportScroller: viewportScroller
        )
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

    // MARK: - Insertion Point
    let insertionPointShape = CurrentValueSubject<InsertionPointShape, Never>(.verticalBar)
    let insertionPointVisibilityMode = CurrentValueSubject<InsertionPointVisibilityMode, Never>(.hiddenWhenMovingUnlessFarAway)
    let insertionPointBackgroundColor = CurrentValueSubject<MultiPlatformColor, Never>(.label)
    #if os(iOS)
    let insertionPointPlaceholderBackgroundColor = CurrentValueSubject<MultiPlatformColor, Never>(.insertionPointPlaceholderBackgroundColor)
    #else
    var insertionPointPlaceholderBackgroundColor: CurrentValueSubject<MultiPlatformColor, Never> {
        insertionPointBackgroundColor
    }
    #endif
    let insertionPointTextColor = CurrentValueSubject<MultiPlatformColor, Never>(.label)
    let insertionPointInvisibleCharacterColor = CurrentValueSubject<MultiPlatformColor, Never>(.label)
    private let floatingInsertionPointPosition = CurrentValueSubject<CGPoint?, Never>(nil)
    var insertionPointLayouter: InsertionPointLayouter {
        InsertionPointLayouter(
            insertionPointViewFactory: InsertionPointViewFactory(
                insertionPointRenderer: insertionPointRenderer
            ),
            frame: insertionPointFramePublisherFactory.makeFramePublisher(),
            containerView: textView,
            isInsertionPointVisible: isInsertionPointVisible,
            isInsertionPointBeingMoved: isInsertionPointBeingMoved
        )
    }
    private var insertionPointRenderer: InsertionPointRenderer {
        InsertionPointCompositeRenderer(renderers: [
            insertionPointBackgroundRenderer(isInsertionPointBeingMoved: isInsertionPointBeingMoved),
            insertionPointForegroundRenderer(),
        ])
    }
    private var floatingInsertionPointRenderer: InsertionPointRenderer {
        InsertionPointCompositeRenderer(renderers: [
            insertionPointBackgroundRenderer(isInsertionPointBeingMoved: Just(false).eraseToAnyPublisher()),
            insertionPointForegroundRenderer(opacity: 0.6)
        ])
    }
    private func insertionPointBackgroundRenderer(isInsertionPointBeingMoved: AnyPublisher<Bool, Never>) -> InsertionPointBackgroundRenderer {
        InsertionPointBackgroundRenderer(
            insertionPointShape: insertionPointShape,
            isInsertionPointBeingMoved: isInsertionPointBeingMoved,
            insertionPointBackgroundColor: insertionPointBackgroundColor,
            insertionPointPlaceholderBackgroundColor: insertionPointPlaceholderBackgroundColor,
            textViewBackgroundColor: textViewBackgroundColor
        )
    }
    private func insertionPointForegroundRenderer(opacity: CGFloat = 1) -> InsertionPointForegroundRenderer {
        InsertionPointForegroundRenderer(
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage,
            selectedRange: selectedRange,
            insertionPointShape: insertionPointShape,
            invisibleCharacterRenderer: invisibleCharacterRenderer,
            insertionPointTextColor: insertionPointTextColor,
            insertionPointInvisibleCharacterColor: insertionPointInvisibleCharacterColor,
            opacity: opacity
        )
    }
    private var insertionPointFramePublisherFactory: InsertionPointFramePublisherFactory {
        InsertionPointFramePublisherFactory(
            insertionPointFrameFactory: insertionPointFrameFactory,
            selectedRange: selectedRange.eraseToAnyPublisher(),
            insertionPointShape: insertionPointShape.eraseToAnyPublisher(),
            contentArea: contentArea,
            estimatedLineHeight: estimatedLineHeight,
            estimatedCharacterWidth: estimatedCharacterWidth.rawValue.eraseToAnyPublisher(),
            kern: typesetSettings.kern.eraseToAnyPublisher()
        )
    }
    private var insertionPointFrameFactory: InsertionPointFrameFactory {
        InsertionPointFrameFactory(
            lineManager: lineManager,
            characterBoundsProvider: characterBoundsProvider,
            lineControllerStorage: lineControllerStorage,
            insertionPointShape: insertionPointShape,
            contentArea: contentArea,
            estimatedLineHeight: estimatedLineHeight,
            estimatedCharacterWidth: estimatedCharacterWidth.rawValue
        )
    }
    private var isInsertionPointVisible: AnyPublisher<Bool, Never> {
        InsertionPointVisiblePublisherFactory(
            selectedRange: selectedRange.eraseToAnyPublisher(),
            isKeyWindow: keyWindowObserver.isKeyWindow.eraseToAnyPublisher(),
            isFirstResponder: isFirstResponder.eraseToAnyPublisher(),
            insertionPointVisibilityMode: insertionPointVisibilityMode.eraseToAnyPublisher(),
            floatingInsertionPointPosition: floatingInsertionPointPosition.eraseToAnyPublisher(),
            insertionPointFrame: insertionPointFramePublisherFactory.makeFramePublisher()
        ).makePublisher()
    }
    private var characterBoundsProvider: CharacterBoundsProvider {
        CharacterBoundsProvider(
            stringView: stringView,
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage,
            contentArea: contentArea
        )
    }

    // MARK: - Text Selection
    private var textSelectionRectFactory: TextSelectionRectFactory {
        TextSelectionRectFactory(
            characterBoundsProvider: characterBoundsProvider,
            lineManager: lineManager,
            contentArea: contentArea,
            lineHeightMultiplier: typesetSettings.lineHeightMultiplier
        )
    }

    // MARK: - Line Selection
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

    // MARK: - Invisible Characters
    private(set) lazy var invisibleCharacterSettings = InvisibleCharacterSettings(
        font: themeSettings.font,
        textColor: themeSettings.invisibleCharactersColor
    )
    private var invisibleCharacterRenderer: InvisibleCharacterRenderer {
        InvisibleCharacterRenderer(
            stringView: stringView,
            invisibleCharacterSettings: invisibleCharacterSettings
        )
    }

    // MARK: - Gutter
    private var gutterWidthService: GutterWidthService {
        GutterWidthService(lineManager: lineManager)
    }

    // MARK: - Indentation
    var indentationChecker: IndentationChecker {
        IndentationChecker(
            stringView: stringView,
            lineManager: lineManager,
            indentStrategy: typesetSettings.indentStrategy
        )
    }

    // MARK: - Page Guide
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

    // MARK: - Search and Replace
    var searchService: SearchService {
        SearchService(
            stringView: stringView,
            textLocationConverter: textLocationConverter
        )
    }
    var batchReplacer: BatchReplacer {
        BatchReplacer(
            stringView: stringView,
            lineManager: lineManager,
            selectedRange: selectedRange,
            textSetter: textSetter
        )
    }
    var textPreviewFactory: TextPreviewFactory {
        TextPreviewFactory(
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage
        )
    }
    var highlightedRangeFragmentStore: HighlightedRangeFragmentStore {
        HighlightedRangeFragmentStore(
            stringView: stringView,
            lineManager: lineManager
        )
    }
    var highlightedRangeNavigator: HighlightedRangeNavigator {
        HighlightedRangeNavigator(
            textView: textView,
            textViewDelegate: textViewDelegate,
            selectedRange: selectedRange,
            highlightedRanges: highlightedRangeFragmentStore.highlightedRanges,
            viewportScroller: viewportScroller,
            editMenuPresenter: editMenuPresenter
        )
    }
    private var editMenuPresenter: EditMenuPresenter {
        #if os(iOS)
        EditMenuPresenter_iOS(referenceView: textView, editMenuController: editMenuController)
        #else
        EditMenuPresenter_Mac()
        #endif
    }

    // MARK: - Syntax Highlighting
    let languageMode = CurrentValueSubject<InternalLanguageMode, Never>(PlainTextInternalLanguageMode())
    var syntaxNodeRaycaster: SyntaxNodeRaycaster {
        SyntaxNodeRaycaster(lineManager: lineManager, languageMode: languageMode)
    }
    var languageModeSetter: LanguageModeSetter {
        LanguageModeSetter(
            stringView: stringView,
            languageMode: languageMode,
            internalLanguageModeFactory: internalLanguageModeFactory
        )
    }
    private var syntaxHighlighterFactory: SyntaxHighlighterFactory {
        SyntaxHighlighterFactory(theme: themeSettings.theme, languageMode: languageMode)
    }
    private var internalLanguageModeFactory: InternalLanguageModeFactory {
        InternalLanguageModeFactory(stringView: stringView, lineManager: lineManager)
    }

    // MARK: - iOS
    #if os(iOS)
    let beginEditingGestureRecognizer: UIGestureRecognizer = QuickTapGestureRecognizer()
    private lazy var textInputDelegate: TextInputDelegate = TextInputDelegate_iOS(textView: textView)
    private var keyWindowObserver: KeyWindowObserver {
        KeyWindowObserver_iOS()
    }
    private(set) lazy var textInteractionManager = UITextInteractionManager(
        textView: textView,
        isEditable: editorState.isEditable,
        isSelectable: editorState.isSelectable,
        beginEditingGestureRecognizer: beginEditingGestureRecognizer,
        textSelectionViewManager: textSelectionViewManager
    )
    var memoryWarningObserver: MemoryWarningObserver {
        MemoryWarningObserver(handlers: [
            LineControllerStorageLowMemoryHandler(
                lineControllerStorage: lineControllerStorage,
                lineFragmentLayouter: lineFragmentLayouter
            )
        ])
    }
    private(set) lazy var textInputHelper = UITextInputHelper(
        textView: textView,
        inputDelegate: textInputDelegate,
        textViewDelegate: textViewDelegate,
        textInteractionManager: textInteractionManager,
        textSelectionViewManager: textSelectionViewManager,
        stringView: stringView,
        selectedRange: selectedRange,
        markedRange: markedRange,
        insertionPointFrameFactory: insertionPointFrameFactory,
        insertionPointShape: insertionPointShape,
        floatingInsertionPointPosition: floatingInsertionPointPosition,
        insertionPointViewFactory: InsertionPointViewFactory(
            insertionPointRenderer: floatingInsertionPointRenderer
        ),
        textEditState: textEditState,
        textInserter: textInserter,
        textDeleter: textDeleter,
        textReplacer: textReplacer,
        textSelectionRectFactory: textSelectionRectFactory,
        firstRectFactory: firstRectFactory,
        locationRaycaster: locationRaycaster,
        characterNavigationLocationFactory: characterNavigationLocationFactory,
        lineNavigationLocationFactory: lineNavigationLocationFactory
    )
    var textRangeAdjustmentGestureTracker: UITextRangeAdjustmentGestureTracker {
        UITextRangeAdjustmentGestureTracker(selectedRange: selectedRange, viewportScroller: viewportScroller)
    }
    private(set) lazy var textSelectionViewManager = UITextSelectionViewManager(
        textView: textView,
        insertionPointFrame: insertionPointFramePublisherFactory.makeFramePublisher(),
        floatingInsertionPointPosition: floatingInsertionPointPosition,
        insertionPointViewFactory: InsertionPointViewFactory(
            insertionPointRenderer: floatingInsertionPointRenderer
        )
    )
    var textSearchingHelper: UITextSearchingHelper {
        UITextSearchingHelper(textView: textView)
    }
    private lazy var isInsertionPointBeingMoved = floatingInsertionPointPosition.map { $0 != nil }.eraseToAnyPublisher()
    private var editMenuController: EditMenuController {
        EditMenuController()
    }

    func textInputStringTokenizer(for textInput: UIResponder & UITextInput) -> UITextInputStringTokenizer {
        TextInputStringTokenizer(textInput: textInput, stringTokenizer: stringTokenizer)
    }
    #endif

    // MARK: - macOS
    #if os(macOS)
    private var textInputDelegate: TextInputDelegate = TextInputDelegate_Mac()
    private(set) lazy var keyWindowObserver: KeyWindowObserver = KeyWindowObserver_Mac(referenceView: textView)
    var textSelectionLayouter: TextSelectionLayouter {
        TextSelectionLayouter(
            textSelectionRectFactory: textSelectionRectFactory,
            containerView: textView,
            viewport: textContainer.viewport,
            selectedRange: selectedRange
        )
    }
    private let isInsertionPointBeingMoved = CurrentValueSubject<Bool, Never>(false).eraseToAnyPublisher()
    #endif
}
