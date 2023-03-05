import Combine
import Foundation

final class CompositionRoot {
    let stringView = StringView()
    private(set) lazy var estimatedLineHeight = EstimatedLineHeight(
        font: themeSettings.font.eraseToAnyPublisher(),
        lineHeightMultiplier: typesetSettings.lineHeightMultiplier.eraseToAnyPublisher()
    )
    private(set) lazy var lineManager = LineManager(stringView: stringView)
    let textContainer = TextContainer()
    let typesetSettings = TypesetSettings()
    private(set) lazy var invisibleCharacterSettings = InvisibleCharacterSettings(
        font: themeSettings.font,
        textColor: themeSettings.invisibleCharactersColor
    )
    let themeSettings = ThemeSettings()
    private(set) lazy var languageMode = CurrentValueSubject<InternalLanguageMode, Never>(
        PlainTextInternalLanguageMode(theme: themeSettings.theme, kern: typesetSettings.kern)
    )
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
    private(set) lazy var contentAreaProvider = ContentAreaProvider(
        viewport: textContainer.viewport,
        contentSize: contentSizeService.contentSize,
        textContainerInset: textContainer.inset
    )
    private(set) lazy var highlightedRangeService = HighlightedRangeService(lineManager: lineManager)
    let theme = CurrentValueSubject<Theme, Never>(DefaultTheme())

    private let textView: TextView
    private lazy var totalLineHeightTracker = TotalLineHeightTracker(lineManager: lineManager)

    init(textView: TextView) {
        self.textView = textView
    }

    var textSelectionLayouter: TextSelectionLayouter {
        TextSelectionLayouter(
            textSelectionRectProvider: textSelectionRectProvider,
            containerView: textView
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
            lineManager: lineManager,
            caretRectProvider: caretRectProvider,
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

    var caretRectProvider: CaretRectProvider {
        CaretRectProvider(
            stringView: stringView,
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage,
            contentAreaProvider: contentAreaProvider
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
    private var textSelectionRectProvider: TextSelectionRectProvider {
        TextSelectionRectProvider(
            lineManager: lineManager,
            contentAreaProvider: contentAreaProvider,
            caretRectProvider: caretRectProvider,
            lineHeightMultiplier: typesetSettings.lineHeightMultiplier
        )
    }

    private var lineControllerFactory: LineControllerFactory {
        LineControllerFactory(
            stringView: stringView,
            highlightedRangeService: highlightedRangeService,
            typesetSettings: typesetSettings,
            invisibleCharacterSettings: invisibleCharacterSettings
        )
    }
}
