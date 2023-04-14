import Combine
import Foundation
@testable import Runestone

final class CompositionRoot {
    let stringView = CurrentValueSubject<StringView, Never>(StringView())
    let insertionPointShape = CurrentValueSubject<InsertionPointShape, Never>(.verticalBar)
    private lazy var lineManager = CurrentValueSubject<LineManager, Never>(LineManager(stringView: stringView.value))
    private let themeSettings = ThemeSettings()
    private lazy var typesetSettings = TypesetSettings(font: themeSettings.font)
    private lazy var estimatedLineHeight = EstimatedLineHeight(
        font: themeSettings.font.eraseToAnyPublisher(),
        lineHeightMultiplier: typesetSettings.lineHeightMultiplier.eraseToAnyPublisher()
    )
    private(set) lazy var estimatedCharacterWidth = EstimatedCharacterWidth(font: themeSettings.font)
    private lazy var invisibleCharacterSettings = InvisibleCharacterSettings(
        font: themeSettings.font,
        textColor: themeSettings.textColor
    )
    private lazy var defaultStringAttributes = DefaultStringAttributes(
        font: themeSettings.font,
        textColor: themeSettings.textColor,
        kern: typesetSettings.kern
    )
    private lazy var rendererFactory = RendererFactory(stringView: stringView, invisibleCharacterSettings: invisibleCharacterSettings)
    private let languageMode = CurrentValueSubject<InternalLanguageMode, Never>(PlainTextInternalLanguageMode())
    private lazy var syntaxHighlighterFactory = SyntaxHighlighterFactory(theme: themeSettings.theme, languageMode: languageMode)
    private lazy var lineControllerFactory = LineControllerFactory(
        stringView: stringView,
        estimatedLineHeight: estimatedLineHeight,
        defaultStringAttributes: defaultStringAttributes,
        typesetSettings: typesetSettings,
        invisibleCharacterSettings: invisibleCharacterSettings,
        rendererFactory: rendererFactory,
        syntaxHighlighterFactory: syntaxHighlighterFactory
    )
    private lazy var lineControllerStorage = LineControllerStorage(stringView: stringView, lineControllerFactory: lineControllerFactory)
    private let contentSize = CurrentValueSubject<CGSize, Never>(CGSize(width: 500, height: 1000))
    private let textContainer = TextContainer()
    private lazy var contentArea = ContentArea(
        viewport: textContainer.viewport,
        contentSize: contentSize,
        textContainerInset: textContainer.inset
    )
    private let scrollView = CurrentValueSubject<WeakBox<MultiPlatformScrollView>, Never>(WeakBox())
    private let containerView = CurrentValueSubject<WeakBox<TextView>, Never>(WeakBox())
    private let widestLineTracker = WidestLineTracker()
    private lazy var totalLineHeightTracker = TotalLineHeightTracker(lineManager: lineManager)
    private let isLineWrappingEnabled = CurrentValueSubject<Bool, Never>(true)
    private lazy var lineFragmentLayouter = LineFragmentLayouter(
        scrollView: scrollView,
        stringView: stringView,
        lineManager: lineManager,
        lineControllerStorage: lineControllerStorage,
        widestLineTracker: widestLineTracker,
        totalLineHeightTracker: totalLineHeightTracker,
        textContainer: textContainer,
        isLineWrappingEnabled: isLineWrappingEnabled,
        contentSize: contentSize,
        containerView: containerView
    )
    var characterBoundsProvider: CharacterBoundsProvider {
        CharacterBoundsProvider(
            stringView: stringView,
            lineManager: lineManager,
            lineControllerStorage: lineControllerStorage,
            contentArea: contentArea
        )
    }
    var insertionPointFrameFactory: InsertionPointFrameFactory {
        InsertionPointFrameFactory(
            lineManager: lineManager,
            characterBoundsProvider: characterBoundsProvider,
            shape: insertionPointShape,
            contentArea: contentArea.rawValue,
            estimatedLineHeight: estimatedLineHeight,
            estimatedCharacterWidth: estimatedCharacterWidth.rawValue
        )
    }

    init() {}

    init(preparingToDisplay string: String) {
        stringView.value.string = string as NSString
        lineManager.value.rebuild()
        textContainer.viewport.value = CGRect(x: 0, y: 0, width: 500, height: 500)
        lineFragmentLayouter.layoutLines(toLocation: string.utf16.count)
    }
}
