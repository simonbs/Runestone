import CoreGraphics

protocol InvisibleCharacterConfigurationReadable {
    var showTabs: Bool { get }
    var showSpaces: Bool { get }
    var showNonBreakingSpaces: Bool { get }
    var showLineBreaks: Bool { get }
    var showSoftLineBreaks: Bool { get }
    var tabSymbol: String { get }
    var spaceSymbol: String { get }
    var nonBreakingSpaceSymbol: String { get }
    var lineBreakSymbol: String { get }
    var softLineBreakSymbol: String { get }
    var maximumLineBreakSymbolWidth: CGFloat { get }
}

extension InvisibleCharacterConfigurationReadable {
    var showInvisibleCharacters: Bool {
        showTabs
        || showSpaces
        || showNonBreakingSpaces
        || showLineBreaks
        || showSoftLineBreaks
    }
}
