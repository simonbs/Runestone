import Combine
import Foundation

final class CompositionRoot {
    private(set) lazy var keyWindowObserver = KeyWindowObserver(referenceView: textView)
    let isFirstResponder = CurrentValueSubject<Bool, Never>(false)
    let selectedRange = CurrentValueSubject<NSRange, Never>(NSRange(location: 0, length: 0))
    let stringView = CurrentValueSubject<StringView, Never>(StringView())
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
    let typesetSettings = TypesetSettings()
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
    private(set) lazy var highlightedRangeService = HighlightedRangeService(lineManager: lineManager)

    private unowned let textView: TextView
    private lazy var totalLineHeightTracker = TotalLineHeightTracker(lineManager: lineManager)

    init(textView: TextView) {
        self.textView = textView
    }

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

    var lineFragmentLayouter: LineFragmentLayouter {
        LineFragmentLayouter(
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
    }

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

    var navigationService: NavigationService {
        NavigationService(
            stringView: stringView,
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage
        )
    }

    #if os(macOS)
    var selectionService: SelectionService {
        SelectionService(
            stringView: stringView,
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage
        )
    }

    var textSelectionLayouter: TextSelectionLayouter {
        TextSelectionLayouter(
            textSelectionRectFactory: textSelectionRectFactory,
            containerView: textView,
            viewport: textContainer.viewport,
            selectedRange: selectedRange
        )
    }
    #endif

    var indentController: IndentController {
        IndentController(
            stringView: stringView,
            lineManager: lineManager,
            languageMode: languageMode,
            font: themeSettings.font
        )
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
}
