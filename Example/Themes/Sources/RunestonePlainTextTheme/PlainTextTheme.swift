#if os(macOS)
import AppKit
#endif
import Runestone
import RunestoneThemeCommon
#if os(iOS)
import UIKit
#endif

public final class PlainTextTheme: EditorTheme {
    public let backgroundColor: MultiPlatformColor = .white
    #if os(iOS)
    public let userInterfaceStyle: UIUserInterfaceStyle = .light
    #endif

    public let font: MultiPlatformFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    public let textColor: MultiPlatformColor = .black

    public let gutterBackgroundColor: MultiPlatformColor = .white
    public let gutterHairlineColor: MultiPlatformColor = .white

    public let lineNumberColor: MultiPlatformColor = .black.withAlphaComponent(0.5)
    public let lineNumberFont: MultiPlatformFont = .monospacedSystemFont(ofSize: 14, weight: .regular)

    public let selectedLineBackgroundColor: MultiPlatformColor = .black.withAlphaComponent(0.07)
    public let selectedLinesLineNumberColor: MultiPlatformColor = .black
    public let selectedLinesGutterBackgroundColor: MultiPlatformColor = .black.withAlphaComponent(0.07)

    public let invisibleCharactersColor: MultiPlatformColor = .black.withAlphaComponent(0.5)

    public let pageGuideHairlineColor: MultiPlatformColor = .black.withAlphaComponent(0.1)
    public let pageGuideBackgroundColor: MultiPlatformColor = .black.withAlphaComponent(0.06)

    public let markedTextBackgroundColor: MultiPlatformColor = .black.withAlphaComponent(0.1)
    public let markedTextBackgroundCornerRadius: CGFloat = 4

    public init() {}

    public func textColor(for rawHighlightName: String) -> MultiPlatformColor? {
        nil
    }

    public func fontTraits(for rawHighlightName: String) -> FontTraits {
        if let highlightName = HighlightName(rawHighlightName), highlightName == .keyword {
            return .bold
        } else {
            return []
        }
    }
}
