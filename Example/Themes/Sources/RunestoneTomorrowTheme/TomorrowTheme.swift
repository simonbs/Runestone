#if os(macOS)
import AppKit
#endif
import Runestone
import RunestoneThemeCommon
#if os(iOS)
import UIKit
#endif

public final class TomorrowTheme: EditorTheme {
    public let backgroundColor = MultiPlatformColor(namedInModule: "TomorrowBackground")
    #if os(iOS)
    public let userInterfaceStyle: UIUserInterfaceStyle = .light
    #endif

    public let font: MultiPlatformFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    public let textColor = MultiPlatformColor(namedInModule: "TomorrowForeground")

    public let gutterBackgroundColor = MultiPlatformColor(namedInModule: "TomorrowCurrentLine")
    public let gutterHairlineColor = MultiPlatformColor(namedInModule: "TomorrowComment")

    public let lineNumberColor = MultiPlatformColor(namedInModule: "TomorrowForeground").withAlphaComponent(0.5)
    public let lineNumberFont: MultiPlatformFont = .monospacedSystemFont(ofSize: 14, weight: .regular)

    public let selectedLineBackgroundColor = MultiPlatformColor(namedInModule: "TomorrowCurrentLine")
    public let selectedLinesLineNumberColor = MultiPlatformColor(namedInModule: "TomorrowForeground")
    public let selectedLinesGutterBackgroundColor: MultiPlatformColor = .clear

    public let invisibleCharactersColor = MultiPlatformColor(namedInModule: "TomorrowForeground").withAlphaComponent(0.7)

    public let pageGuideHairlineColor = MultiPlatformColor(namedInModule: "TomorrowForeground")
    public let pageGuideBackgroundColor = MultiPlatformColor(namedInModule: "TomorrowCurrentLine")

    public let markedTextBackgroundColor = MultiPlatformColor(namedInModule: "TomorrowForeground").withAlphaComponent(0.1)
    public let markedTextBackgroundCornerRadius: CGFloat = 4

    public init() {}

    public func textColor(for rawHighlightName: String) -> MultiPlatformColor? {
        guard let highlightName = HighlightName(rawHighlightName) else {
            return nil
        }
        switch highlightName {
        case .comment:
            return MultiPlatformColor(namedInModule: "TomorrowComment")
        case .operator, .punctuation:
            return MultiPlatformColor(namedInModule: "TomorrowForeground").withAlphaComponent(0.75)
        case .property:
            return MultiPlatformColor(namedInModule: "TomorrowAqua")
        case .function:
            return MultiPlatformColor(namedInModule: "TomorrowBlue")
        case .string:
            return MultiPlatformColor(namedInModule: "TomorrowGreen")
        case .number:
            return MultiPlatformColor(namedInModule: "TomorrowOrange")
        case .keyword:
            return MultiPlatformColor(namedInModule: "TomorrowPurple")
        case .variableBuiltin, .constantBuiltin:
            return MultiPlatformColor(namedInModule: "TomorrowRed")
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
