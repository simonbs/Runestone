#if os(macOS)
import AppKit
#endif
import Runestone
import RunestoneThemeCommon
#if os(iOS)
import UIKit
#endif

public final class TomorrowNightTheme: EditorTheme {
    public let backgroundColor = MultiPlatformColor(namedInModule: "TomorrowNightBackground")
    #if os(iOS)
    public let userInterfaceStyle: UIUserInterfaceStyle = .dark
    #endif

    public let font: MultiPlatformFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    public let textColor = MultiPlatformColor(namedInModule: "TomorrowNightForeground")

    public let gutterBackgroundColor = MultiPlatformColor(namedInModule: "TomorrowNightCurrentLine")
    public let gutterHairlineColor = MultiPlatformColor(namedInModule: "TomorrowNightComment")

    public let lineNumberColor = MultiPlatformColor(namedInModule: "TomorrowNightForeground").withAlphaComponent(0.5)
    public let lineNumberFont: MultiPlatformFont = .monospacedSystemFont(ofSize: 14, weight: .regular)

    public let selectedLineBackgroundColor = MultiPlatformColor(namedInModule: "TomorrowNightCurrentLine")
    public let selectedLinesLineNumberColor = MultiPlatformColor(namedInModule: "TomorrowNightForeground")
    public let selectedLinesGutterBackgroundColor: MultiPlatformColor = .clear

    public let invisibleCharactersColor = MultiPlatformColor(namedInModule: "TomorrowNightForeground").withAlphaComponent(0.7)

    public let pageGuideHairlineColor = MultiPlatformColor(namedInModule: "TomorrowNightForeground")
    public let pageGuideBackgroundColor = MultiPlatformColor(namedInModule: "TomorrowNightCurrentLine")

    public let markedTextBackgroundColor = MultiPlatformColor(namedInModule: "TomorrowNightForeground").withAlphaComponent(0.1)
    public let markedTextBackgroundCornerRadius: CGFloat = 4

    public init() {}

    public func textColor(for rawHighlightName: String) -> MultiPlatformColor? {
        guard let highlightName = HighlightName(rawHighlightName) else {
            return nil
        }
        switch highlightName {
        case .comment:
            return MultiPlatformColor(namedInModule: "TomorrowNightComment")
        case .operator, .punctuation:
            return MultiPlatformColor(namedInModule: "TomorrowNightForeground").withAlphaComponent(0.75)
        case .property:
            return MultiPlatformColor(namedInModule: "TomorrowNightAqua")
        case .function:
            return MultiPlatformColor(namedInModule: "TomorrowNightBlue")
        case .string:
            return MultiPlatformColor(namedInModule: "TomorrowNightGreen")
        case .number:
            return MultiPlatformColor(namedInModule: "TomorrowNightOrange")
        case .keyword:
            return MultiPlatformColor(namedInModule: "TomorrowNightPurple")
        case .variableBuiltin, .constantBuiltin:
            return MultiPlatformColor(namedInModule: "TomorrowNightRed")
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
