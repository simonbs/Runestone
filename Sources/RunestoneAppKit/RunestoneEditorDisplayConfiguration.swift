#if canImport(AppKit)
import AppKit

public enum RunestoneSelectedLineHighlightGranularity: String, CaseIterable {
    case line
    case lineFragment
}

/// AppKit-owned presentation options for a Runestone document surface.
/// These values never mutate document text, input state, undo, or file metadata.
public struct RunestoneEditorDisplayConfiguration {
    public var showsLineNumbers: Bool
    public var minimumGutterCharacterCount: Int
    public var showsSelectedLines: Bool
    public var selectedLineHighlightGranularity: RunestoneSelectedLineHighlightGranularity
    public var showsTabs: Bool
    public var showsSpaces: Bool
    public var showsNonBreakingSpaces: Bool
    public var showsLineBreaks: Bool
    public var showsSoftLineBreaks: Bool
    public var tabSymbol: String
    public var spaceSymbol: String
    public var nonBreakingSpaceSymbol: String
    public var lineBreakSymbol: String
    public var softLineBreakSymbol: String
    public var lineNumberFont: NSFont
    public var lineNumberColor: NSColor
    public var selectedLineNumberColor: NSColor
    public var gutterBackgroundColor: NSColor
    public var selectedLineBackgroundColor: NSColor
    public var invisibleCharacterColor: NSColor
    public var pageGuideColumn: Int?
    public var pageGuideColor: NSColor
    public var maximumContentWidthColumn: Int?
    public var characterWidth: CGFloat

    public init(
        showsLineNumbers: Bool = false, minimumGutterCharacterCount: Int = 1,
        showsSelectedLines: Bool = false,
        selectedLineHighlightGranularity: RunestoneSelectedLineHighlightGranularity = .line,
        showsTabs: Bool = false, showsSpaces: Bool = false,
        showsNonBreakingSpaces: Bool = false, showsLineBreaks: Bool = false,
        showsSoftLineBreaks: Bool = false, tabSymbol: String = "▸", spaceSymbol: String = "·",
        nonBreakingSpaceSymbol: String = "·", lineBreakSymbol: String = "¬", softLineBreakSymbol: String = "¬",
        lineNumberFont: NSFont = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular),
        lineNumberColor: NSColor = .secondaryLabelColor, selectedLineNumberColor: NSColor = .labelColor,
        gutterBackgroundColor: NSColor = .textBackgroundColor,
        selectedLineBackgroundColor: NSColor = .selectedContentBackgroundColor.withAlphaComponent(0.08),
        invisibleCharacterColor: NSColor = .tertiaryLabelColor, pageGuideColumn: Int? = nil,
        pageGuideColor: NSColor = .separatorColor, maximumContentWidthColumn: Int? = nil,
        characterWidth: CGFloat = 8
    ) {
        self.showsLineNumbers = showsLineNumbers
        self.minimumGutterCharacterCount = minimumGutterCharacterCount
        self.showsSelectedLines = showsSelectedLines
        self.selectedLineHighlightGranularity = selectedLineHighlightGranularity
        self.showsTabs = showsTabs
        self.showsSpaces = showsSpaces
        self.showsNonBreakingSpaces = showsNonBreakingSpaces
        self.showsLineBreaks = showsLineBreaks
        self.showsSoftLineBreaks = showsSoftLineBreaks
        self.tabSymbol = tabSymbol
        self.spaceSymbol = spaceSymbol
        self.nonBreakingSpaceSymbol = nonBreakingSpaceSymbol
        self.lineBreakSymbol = lineBreakSymbol
        self.softLineBreakSymbol = softLineBreakSymbol
        self.lineNumberFont = lineNumberFont
        self.lineNumberColor = lineNumberColor
        self.selectedLineNumberColor = selectedLineNumberColor
        self.gutterBackgroundColor = gutterBackgroundColor
        self.selectedLineBackgroundColor = selectedLineBackgroundColor
        self.invisibleCharacterColor = invisibleCharacterColor
        self.pageGuideColumn = pageGuideColumn
        self.pageGuideColor = pageGuideColor
        self.maximumContentWidthColumn = maximumContentWidthColumn
        self.characterWidth = characterWidth
    }
}
#endif
