#if os(macOS)
import AppKit
#endif
import Runestone
import RunestoneThemeCommon
#if os(iOS)
import UIKit
#endif

public final class OneDarkTheme: EditorTheme {
    public let backgroundColor = MultiPlatformColor(namedInModule: "OneDarkBackground")
    #if os(iOS)
    public let userInterfaceStyle: UIUserInterfaceStyle = .dark
    #endif

    public let font: MultiPlatformFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    public let textColor = MultiPlatformColor(namedInModule: "OneDarkForeground")

    public let gutterBackgroundColor = MultiPlatformColor(namedInModule: "OneDarkCurrentLine")
    #if os(iOS)
    public let gutterHairlineColor: MultiPlatformColor = .opaqueSeparator
    #else
    public let gutterHairlineColor: MultiPlatformColor = .separatorColor
    #endif

    public let lineNumberColor = MultiPlatformColor(namedInModule: "OneDarkForeground").withAlphaComponent(0.5)
    public let lineNumberFont: MultiPlatformFont = .monospacedSystemFont(ofSize: 14, weight: .regular)

    public let selectedLineBackgroundColor = MultiPlatformColor(namedInModule: "OneDarkCurrentLine")
    public let selectedLinesLineNumberColor = MultiPlatformColor(namedInModule: "OneDarkForeground")
    public let selectedLinesGutterBackgroundColor: MultiPlatformColor = .clear

    public let invisibleCharactersColor = MultiPlatformColor(namedInModule: "OneDarkForeground").withAlphaComponent(0.7)

    public let pageGuideHairlineColor = MultiPlatformColor(namedInModule: "OneDarkForeground")
    public let pageGuideBackgroundColor = MultiPlatformColor(namedInModule: "OneDarkCurrentLine")

    public let markedTextBackgroundColor = MultiPlatformColor(namedInModule: "OneDarkForeground").withAlphaComponent(0.1)
    public let markedTextBackgroundCornerRadius: CGFloat = 4

    public init() {}

    public func textColor(for rawHighlightName: String) -> MultiPlatformColor? {
        guard let highlightName = HighlightName(rawHighlightName) else {
            return nil
        }
        switch highlightName {
        case .comment:
            return MultiPlatformColor(namedInModule: "OneDarkComment")
        case .operator, .punctuation:
            return MultiPlatformColor(namedInModule: "OneDarkForeground").withAlphaComponent(0.75)
        case .property:
            return MultiPlatformColor(namedInModule: "OneDarkAqua")
        case .function:
            return MultiPlatformColor(namedInModule: "OneDarkBlue")
        case .string:
            return MultiPlatformColor(namedInModule: "OneDarkGreen")
        case .number:
            return MultiPlatformColor(namedInModule: "OneDarkYellow")
        case .keyword:
            return MultiPlatformColor(namedInModule: "OneDarkPurple")
        case .variableBuiltin, .constantBuiltin:
            return MultiPlatformColor(namedInModule: "OneDarkRed")
        }
    }

    public func fontTraits(for rawHighlightName: String) -> FontTraits {
        if let highlightName = HighlightName(rawHighlightName), highlightName == .keyword {
            return .bold
        } else {
            return []
        }
    }
}

#if os(iOS)
public extension UIColor {
    convenience init(namedInModule name: String) {
        self.init(named: name, in: .module, compatibleWith: nil)!
    }
}
#else
public extension NSColor {
    convenience init(namedInModule name: String) {
        self.init(named: name, bundle: .module)!
    }
}
#endif
