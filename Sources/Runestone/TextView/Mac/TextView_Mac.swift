// swiftlint:disable file_length
#if os(macOS)
import AppKit
import Combine
import UniformTypeIdentifiers

// swiftlint:disable:next type_body_length
/// A type similiar to NSTextView with features commonly found in code editors.
///
/// `TextView` is a performant implementation of a text view with features such as showing line numbers, searching for text and replacing results, syntax highlighting, showing invisible characters and more.
///
/// The type does not subclass `NSTextView` but its interface is kept close to `NSTextView`.
///
/// When initially configuring the `TextView` with a theme, a language and the text to be shown, it is recommended to use the ``setState(_:addUndoAction:)`` function.
/// The function takes an instance of ``TextViewState`` as input which can be created on a background queue to avoid blocking the main queue while doing the initial parse of a text.
open class TextView: NSView, NSMenuItemValidation {
    /// Delegate to receive callbacks for events triggered by the editor.
    public weak var editorDelegate: TextViewDelegate? {
        get {
            textViewController.textViewDelegate.delegate
        }
        set {
            textViewController.textViewDelegate.delegate = newValue
        }
    }
    /// Returns a Boolean value indicating whether this object can become the first responder.
    override public var acceptsFirstResponder: Bool {
        true
    }
    /// A Boolean value indicating whether the view uses a flipped coordinate system.
    override public var isFlipped: Bool {
        true
    }
    /// A Boolean value that indicates whether the text view is editable.
    @_RunestoneProxy(\TextView.textViewController.editorState.isEditable.value)
    public var isEditable: Bool
    /// Whether the text view is in a state where the contents can be edited.
    public var isEditing: Bool {
        textViewController.editorState.isEditing.value
    }
    /// The text that the text view displays.
    public var text: String {
        get {
            textViewController.stringView.value.string as String
        }
        set {
            textViewController.textSetter.setText(newValue as NSString)
        }
    }
    /// Colors and fonts to be used by the editor.
    @_RunestoneProxy(\TextView.textViewController.themeSettings.theme.value)
    public var theme: Theme
    /// Character pairs are used by the editor to automatically insert a trailing character when the user types the leading character.
    ///
    /// Common usages of this includes the \" character to surround strings and { } to surround a scope.
    @_RunestoneProxy(\TextView.textViewController.characterPairService.characterPairs)
    public var characterPairs: [CharacterPair]
    /// Determines what should happen to the trailing component of a character pair when deleting the leading component. Defaults to `disabled` meaning that nothing will happen.
    @_RunestoneProxy(\TextView.textViewController.characterPairService.trailingComponentDeletionMode)
    public var characterPairTrailingComponentDeletionMode: CharacterPairTrailingComponentDeletionMode
    /// Enable to show line numbers in the gutter.
//    public var showLineNumbers: Bool {
//        get {
//            textViewController.showLineNumbers
//        }
//        set {
//            textViewController.showLineNumbers = newValue
//        }
//    }
    /// Enable to show highlight the selected lines. The selection is only shown in the gutter when multiple lines are selected.
    @_RunestoneProxy(\TextView.textViewController.lineSelectionLayouter.lineSelectionDisplayType.value)
    public var lineSelectionDisplayType: LineSelectionDisplayType
    /// The text view renders invisible tabs when enabled. The `tabsSymbol` is used to render tabs.
    @_RunestoneProxy(\TextView.textViewController.invisibleCharacterSettings.showTabs.value)
    public var showTabs: Bool
    /// The text view renders invisible spaces when enabled.
    ///
    /// The `spaceSymbol` is used to render spaces.
    @_RunestoneProxy(\TextView.textViewController.invisibleCharacterSettings.showSpaces.value)
    public var showSpaces: Bool
    /// The text view renders invisible spaces when enabled.
    ///
    /// The `nonBreakingSpaceSymbol` is used to render spaces.
    @_RunestoneProxy(\TextView.textViewController.invisibleCharacterSettings.showNonBreakingSpaces.value)
    public var showNonBreakingSpaces: Bool
    /// The text view renders invisible line breaks when enabled.
    ///
    /// The `lineBreakSymbol` is used to render line breaks.
    @_RunestoneProxy(\TextView.textViewController.invisibleCharacterSettings.showLineBreaks.value)
    public var showLineBreaks: Bool
    /// The text view renders invisible soft line breaks when enabled.
    ///
    /// The `softLineBreakSymbol` is used to render line breaks. These line breaks are typically represented by the U+2028 unicode character. Runestone does not provide any key commands for inserting these but supports rendering them.
    @_RunestoneProxy(\TextView.textViewController.invisibleCharacterSettings.showSoftLineBreaks.value)
    public var showSoftLineBreaks: Bool
    /// Symbol used to display tabs.
    ///
    /// The value is only used when invisible tab characters is enabled. The default is ▸.
    ///
    /// Common characters for this symbol include ▸, ⇥, ➜, ➞, and ❯.
    @_RunestoneProxy(\TextView.textViewController.invisibleCharacterSettings.tabSymbol.value)
    public var tabSymbol: String
    /// Symbol used to display spaces.
    ///
    /// The value is only used when showing invisible space characters is enabled. The default is ·.
    ///
    /// Common characters for this symbol include ·, •, and _.
    @_RunestoneProxy(\TextView.textViewController.invisibleCharacterSettings.spaceSymbol.value)
    public var spaceSymbol: String
    /// Symbol used to display non-breaking spaces.
    ///
    /// The value is only used when showing invisible space characters is enabled. The default is ·.
    ///
    /// Common characters for this symbol include ·, •, and _.
    @_RunestoneProxy(\TextView.textViewController.invisibleCharacterSettings.nonBreakingSpaceSymbol.value)
    public var nonBreakingSpaceSymbol: String
    /// Symbol used to display line break.
    ///
    /// The value is only used when showing invisible line break characters is enabled. The default is ¬.
    ///
    /// Common characters for this symbol include ¬, ↵, ↲, ⤶, and ¶.
    @_RunestoneProxy(\TextView.textViewController.invisibleCharacterSettings.lineBreakSymbol.value)
    public var lineBreakSymbol: String
    /// Symbol used to display soft line breaks.
    ///
    /// The value is only used when showing invisible soft line break characters is enabled. The default is ¬.
    ///
    /// Common characters for this symbol include ¬, ↵, ↲, ⤶, and ¶.
    @_RunestoneProxy(\TextView.textViewController.invisibleCharacterSettings.softLineBreakSymbol.value)
    public var softLineBreakSymbol: String
    /// The strategy used when indenting text.
    @_RunestoneProxy(\TextView.textViewController.typesetSettings.indentStrategy.value)
    public var indentStrategy: IndentStrategy
    /// The amount of padding before the line numbers inside the gutter.
//    public var gutterLeadingPadding: CGFloat {
//        get {
//            textViewController.gutterLeadingPadding
//        }
//        set {
//            textViewController.gutterLeadingPadding = newValue
//        }
//    }
    /// The amount of padding after the line numbers inside the gutter.
//    public var gutterTrailingPadding: CGFloat {
//        get {
//            textViewController.gutterTrailingPadding
//        }
//        set {
//            textViewController.gutterTrailingPadding = newValue
//        }
//    }
    /// The minimum amount of characters to use for width calculation inside the gutter.
//    public var gutterMinimumCharacterCount: Int {
//        get {
//            textViewController.gutterMinimumCharacterCount
//        }
//        set {
//            textViewController.gutterMinimumCharacterCount = newValue
//        }
//    }
    /// The amount of spacing surrounding the lines.
    @_RunestoneProxy(\TextView.textViewController.textContainer.inset.value)
    public var textContainerInset: NSEdgeInsets
    /// When line wrapping is disabled, users can scroll the text view horizontally to see the entire line.
    ///
    /// Line wrapping is enabled by default.
    @_RunestoneProxy(\TextView.textViewController.typesetSettings.isLineWrappingEnabled.value)
    public var isLineWrappingEnabled: Bool
    /// Line break mode for text view. The default value is .byWordWrapping meaning that wrapping occurs on word boundaries.
    @_RunestoneProxy(\TextView.textViewController.typesetSettings.lineBreakMode.value)
    public var lineBreakMode: LineBreakMode
    /// Width of the gutter.
//    public var gutterWidth: CGFloat {
//        textViewController.gutterWidthService.gutterWidth
//    }
    /// The line-height is multiplied with the value.
    @_RunestoneProxy(\TextView.textViewController.typesetSettings.lineHeightMultiplier.value)
    public var lineHeightMultiplier: CGFloat
    /// The number of points by which to adjust kern. The default value is 0 meaning that kerning is disabled.
    @_RunestoneProxy(\TextView.textViewController.typesetSettings.kern.value)
    public var kern: CGFloat
    /// The text view shows a page guide when enabled. Use `pageGuideColumn` to specify the location of the page guide.
    @_RunestoneProxy(\TextView.textViewController.pageGuideLayouter.isEnabled)
    public var showPageGuide: Bool
    /// Specifies the location of the page guide. Use `showPageGuide` to specify if the page guide should be shown.
    @_RunestoneProxy(\TextView.textViewController.pageGuideLayouter.column)
    public var pageGuideColumn: Int
    /// Automatically scrolls the text view to show the caret when typing or moving the caret.
    @_RunestoneProxy(\TextView.textViewController.automaticViewportScroller.isAutomaticScrollEnabled)
    public var isAutomaticScrollEnabled: Bool
    /// Amount of overscroll to add in the vertical direction.
    ///
    /// The overscroll is a factor of the scrollable area height and will not take into account any insets. 0 means no overscroll and 1 means an amount equal to the height of the text view. Detaults to 0.
    @_RunestoneProxy(\TextView.textViewController.contentSizeService.verticalOverscrollFactor.value)
    public var verticalOverscrollFactor: CGFloat
    /// Amount of overscroll to add in the horizontal direction.
    ///
    /// The overscroll is a factor of the scrollable area height and will not take into account any insets or the width of the gutter. 0 means no overscroll and 1 means an amount equal to the width of the text view. Detaults to 0.
    @_RunestoneProxy(\TextView.textViewController.contentSizeService.horizontalOverscrollFactor.value)
    public var horizontalOverscrollFactor: CGFloat
    /// The length of the line that was longest when opening the document.
    ///
    /// This will return nil if the line is no longer available. The value will not be kept updated as the text is changed. The value can be used to determine if a document contains a very long line in which case the performance may be degraded when editing the line.
    public var lengthOfInitallyLongestLine: Int? {
        textViewController.lineManager.value.initialLongestLine?.data.totalLength
    }
    /// Ranges in the text to be highlighted. The color defined by the background will be drawen behind the text.
    @_RunestoneProxy(\TextView.textViewController.highlightedRangeFragmentStore.highlightedRanges.value)
    public var highlightedRanges: [HighlightedRange]
    /// Wheter the text view should loop when navigating through highlighted ranges using `selectPreviousHighlightedRange` or `selectNextHighlightedRange` on the text view.
    @_RunestoneProxy(\TextView.textViewController.highlightedRangeNavigator.loopingMode)
    public var highlightedRangeLoopingMode: HighlightedRangeLoopingMode
    /// Line endings to use when inserting a line break.
    ///
    /// The value only affects new line breaks inserted in the text view and changing this value does not change the line endings of the text in the text view. Defaults to Unix (LF).
    ///
    /// The TextView will only update the line endings when text is modified through an external event, such as when the user typing on the keyboard, when the user is replacing selected text, and when pasting text into the text view. In all other cases, you should make sure that the text provided to the text view uses the desired line endings. This includes when calling ``TextView/setState(_:addUndoAction:)``.
    @_RunestoneProxy(\TextView.textViewController.typesetSettings.lineEndings.value)
    public var lineEndings: LineEnding
    /// The color of the insertion point. This can be used to control the color of the caret.
    @_RunestoneProxy(\TextView.textViewController.caretLayouter.color)
    public var insertionPointColor: NSColor
    /// The color of the selection highlight. It is most common to set this to the same color as the color used for the insertion point.
    @_RunestoneProxy(\TextView.textViewController.textSelectionLayouter.backgroundColor.value)
    public var selectionHighlightColor: NSColor
    /// The object that the document uses to support undo/redo operations.
    override open var undoManager: UndoManager? {
        textViewController.undoManager
    }

    private(set) lazy var textViewController = TextViewController(textView: self)
    let textFinder = NSTextFinder()
    var scrollView: NSScrollView? {
        guard let scrollView = enclosingScrollView, scrollView.documentView === self else {
            return nil
        }
        return scrollView
     }

    private let textFinderClient = TextFinderClient()
    private var shouldBeginEditing: Bool {
        guard isEditable else {
            return false
        }
        if let editorDelegate = editorDelegate {
            return editorDelegate.textViewShouldBeginEditing(self)
        } else {
            return true
        }
    }
    private var shouldEndEditing: Bool {
        if let editorDelegate = editorDelegate {
            return editorDelegate.textViewShouldEndEditing(self)
        } else {
            return true
        }
    }
    private var boundsObserver: AnyCancellable?
    private var windowDidResignKeyObserver: AnyCancellable?

    /// Create a new text view.
    public init() {
        super.init(frame: .zero)
        setup()
    }

    /// Create a new text view from a XIB or Storyboard.
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        textViewController.selectedRange.value = NSRange(location: 0, length: 0)
        textViewController.scrollView.value = WeakBox(scrollView)
        setupScrollViewBoundsDidChangeObserver()
        setupMenu()
    }

    /// Create a scroll view with an instance of `TextView` assigned to the document view.
    public static func scrollableTextView() -> NSScrollView {
        let textView = TextView()
        textView.autoresizingMask = [.width, .height]
        let scrollView = NSScrollView()
        scrollView.contentView = FlippedClipView()
        scrollView.documentView = textView
        scrollView.drawsBackground = false
//        scrollView.hasVerticalScroller = true
//        scrollView.hasHorizontalScroller = true
        return scrollView
    }

    /// Informs the view that its superview has changed.
    open override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        textViewController.scrollView.value = WeakBox(scrollView)
        setupScrollViewBoundsDidChangeObserver()
        setupTextFinder()
    }

    /// Notifies the receiver that it's about to become first responder in its NSWindow.
    @discardableResult
    override open func becomeFirstResponder() -> Bool {
        guard !isEditing && shouldBeginEditing else {
            return false
        }
        let didBecomeFirstResponder = super.becomeFirstResponder()
        if didBecomeFirstResponder {
            textViewController.isFirstResponder.value = true
            textViewController.editorState.isEditing.value = true
            editorDelegate?.textViewDidBeginEditing(self)
        } else {
            textViewController.editorState.isEditing.value = false
        }
        return didBecomeFirstResponder
    }

    /// Notifies the receiver that it's been asked to relinquish its status as first responder in its window.
    @discardableResult
    override open func resignFirstResponder() -> Bool {
        guard isEditing && shouldEndEditing else {
            return false
        }
        let didResignFirstResponder = super.resignFirstResponder()
        if didResignFirstResponder {
            textViewController.isFirstResponder.value = false
            textViewController.editorState.isEditing.value = false
            editorDelegate?.textViewDidEndEditing(self)
        }
        return didResignFirstResponder
    }

    /// Perform layout in concert with the constraint-based layout system.
    open override func layout() {
        super.layout()
        updateViewport()
//        textViewController.caretLayouter.layoutIfNeeded()
        textViewController.lineFragmentLayouter.layoutIfNeeded()
//        textViewController.lineSelectionLayouter.layoutIfNeeded()
        textViewController.contentSizeService.updateContentSizeIfNeeded()
    }

    /// Overridden by subclasses to define their default cursor rectangles.
    override public func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .iBeam)
    }

    /// Implemented to override the default action of enabling or disabling a specific menu item.
    /// - Parameter menuItem: An NSMenuItem object that represents the menu item.
    /// - Returns: `true` to enable menuItem, `false` to disable it.
    public func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(copy(_:)) || menuItem.action == #selector(cut(_:)) {
            return selectedRange().length > 0
        } else if menuItem.action == #selector(paste(_:)) {
            return NSPasteboard.general.canReadItem(withDataConformingToTypes: [UTType.plainText.identifier])
        } else if menuItem.action == #selector(selectAll(_:)) {
            return !text.isEmpty
        } else if menuItem.action == #selector(undo(_:)) {
            return undoManager?.canUndo ?? false
        } else if menuItem.action == #selector(redo(_:)) {
            return undoManager?.canRedo ?? false
        } else {
            return true
        }
    }

    /// Sets the current _state_ of the editor. The state contains the text to be displayed by the editor and
    /// various additional information about the text that the editor needs to show the text.
    ///
    /// It is safe to create an instance of <code>TextViewState</code> in the background, and as such it can be
    /// created before presenting the editor to the user, e.g. when opening the document from an instance of
    /// <code>UIDocumentBrowserViewController</code>.
    ///
    /// This is the preferred way to initially set the text, language and theme on the <code>TextView</code>.
    /// - Parameter state: The new state to be used by the editor.
    /// - Parameter addUndoAction: Whether the state change can be undone. Defaults to false.
    public func setState(_ state: TextViewState, addUndoAction: Bool = false) {
        textViewController.textViewStateSetter.setState(state, addUndoAction: addUndoAction)
    }

    /// Returns the row and column at the specified location in the text.
    /// Common usages of this includes showing the line and column that the caret is currently located at.
    /// - Parameter location: The location is relative to the first index in the string.
    /// - Returns: The text location if the input location could be found in the string, otherwise nil.
    public func textLocation(at location: Int) -> TextLocation? {
        textViewController.textLocationConverter.textLocation(at: location)
    }

    /// Returns the character location at the specified row and column.
    /// - Parameter textLocation: The row and column in the text.
    /// - Returns: The location if the input row and column could be found in the text, otherwise nil.
    public func location(at textLocation: TextLocation) -> Int? {
        textViewController.textLocationConverter.location(at: textLocation)
    }

    /// Sets the language mode on a background thread.
    ///
    /// - Parameters:
    ///   - languageMode: The new language mode to be used by the editor.
    ///   - completion: Called when the content have been parsed or when parsing fails.
    public func setLanguageMode(_ languageMode: LanguageMode, completion: ((Bool) -> Void)? = nil) {
        textViewController.languageModeSetter.setLanguageMode(languageMode, completion: completion)
    }

    /// Replaces the text in the specified matches.
    /// - Parameters:
    ///   - batchReplaceSet: Set of ranges to replace with a text.
    public func replaceText(in batchReplaceSet: BatchReplaceSet) {
        textViewController.batchReplacer.replaceText(in: batchReplaceSet)
    }

    /// Returns the syntax node at the specified location in the document.
    ///
    /// This can be used with character pairs to determine if a pair should be inserted or not.
    /// For example, a character pair consisting of two quotes (") to surround a string, should probably not be
    /// inserted when the quote is typed while the caret is already inside a string.
    ///
    /// This requires a language to be set on the editor.
    /// - Parameter location: A location in the document.
    /// - Returns: The syntax node at the location.
    public func syntaxNode(at location: Int) -> SyntaxNode? {
        textViewController.syntaxNodeRaycaster.syntaxNode(at: location)
    }

    /// Checks if the specified locations is within the indentation of the line.
    ///
    /// - Parameter location: A location in the document.
    /// - Returns: True if the location is within the indentation of the line, otherwise false.
    public func isIndentation(at location: Int) -> Bool {
        textViewController.indentationChecker.isIndentation(at: location)
    }

    /// Decreases the indentation level of the selected lines.
    public func shiftLeft() {
        textViewController.textShifter.shiftLeft()
    }

    /// Increases the indentation level of the selected lines.
    public func shiftRight() {
        textViewController.textShifter.shiftRight()
    }

    /// Moves the selected lines up by one line.
    ///
    /// Calling this function has no effect when the selected lines include the first line in the text view.
    public func moveSelectedLinesUp() {
        textViewController.lineMover.moveSelectedLinesUp()
    }

    /// Moves the selected lines down by one line.
    ///
    /// Calling this function has no effect when the selected lines include the last line in the text view.
    public func moveSelectedLinesDown() {
        textViewController.lineMover.moveSelectedLinesDown()
    }

    /// Attempts to detect the indent strategy used in the document. This may return an unknown strategy even
    /// when the document contains indentation.
    public func detectIndentStrategy() -> DetectedIndentStrategy {
        textViewController.languageMode.value.detectIndentStrategy()
    }


    /// Go to the beginning of the line at the specified index.
    ///
    /// - Parameter lineIndex: Index of line to navigate to.
    /// - Parameter selection: The placement of the caret on the line.
    /// - Returns: True if the text view could navigate to the specified line index, otherwise false.
    @discardableResult
    public func goToLine(_ lineIndex: Int, select selection: GoToLineSelection = .beginning) -> Bool {
        textViewController.goToLineNavigator.goToLine(lineIndex, select: selection)
    }

    /// Search for the specified query.
    ///
    /// The code below shows how a ``SearchQuery`` can be constructed and passed to ``search(for:)``.
    ///
    /// ```swift
    /// let query = SearchQuery(text: "foo", matchMethod: .contains, isCaseSensitive: false)
    /// let results = textView.search(for: query)
    /// ```
    ///
    /// - Parameter query: Query to find matches for.
    /// - Returns: Results matching the query.
    public func search(for query: SearchQuery) -> [SearchResult] {
        textViewController.searchService.search(for: query)
    }

    /// Search for the specified query and return results that take a replacement string into account.
    ///
    /// When searching for a regular expression this function will perform pattern matching and take the matched groups into account in the returned results.
    ///
    /// The code below shows how a ``SearchQuery`` can be constructed and passed to ``search(for:replacingMatchesWith:)`` and how the returned search results can be used to perform a replace operation.
    ///
    /// ```swift
    /// let query = SearchQuery(text: "foo", matchMethod: .contains, isCaseSensitive: false)
    /// let results = textView.search(for: query, replacingMatchesWith: "bar")
    /// let replacements = results.map { BatchReplaceSet.Replacement(range: $0.range, text: $0.replacementText) }
    /// let batchReplaceSet = BatchReplaceSet(replacements: replacements)
    /// textView.replaceText(in: batchReplaceSet)
    /// ```
    ///
    /// - Parameters:
    ///   - query: Query to find matches for.
    ///   - replacementString: String to replace matches with. Can refer to groups in a regular expression using $0, $1, $2 etc.
    /// - Returns: Results matching the query.
    public func search(for query: SearchQuery, replacingMatchesWith replacementString: String) -> [SearchReplaceResult] {
        textViewController.searchService.search(for: query, replacingMatchesWith: replacementString)
    }

    /// Returns a peek into the text view's underlying attributed string.
    /// - Parameter range: Range of text to include in text view. The returned result may span a larger range than the one specified.
    /// - Returns: Text preview containing the specified range.
    public func textPreview(containing range: NSRange) -> TextPreview? {
        let textPreviewFactory = TextPreviewFactory(
            lineManager: textViewController.lineManager,
            lineControllerStorage: textViewController.lineControllerStorage
        )
        return textPreviewFactory.textPreview(containing: range)
    }

    /// Selects a highlighted range behind the selected range if possible.
    public func selectPreviousHighlightedRange() {
        textViewController.highlightedRangeNavigator.selectPreviousRange()
    }

    /// Selects a highlighted range after the selected range if possible.
    public func selectNextHighlightedRange() {
        textViewController.highlightedRangeNavigator.selectNextRange()
    }

    /// Selects the highlighed range at the specified index.
    /// - Parameter index: Index of highlighted range to select.
    public func selectHighlightedRange(at index: Int) {
        textViewController.highlightedRangeNavigator.selectRange(at: index)
    }

    /// Synchronously displays the visible lines.
    ///
    /// This can be used to immediately update the visible lines after setting the theme.
    ///
    /// Use with caution as redisplaying the visible lines can be a costly operation.
//    public func redisplayVisibleLines() {
//        textViewController.redisplayVisibleLines()
//    }

    /// Scrolls the text view to reveal the text in the specified range.
    ///
    /// The function will scroll the text view as little as possible while revealing as much as possible of the specified range. It is not guaranteed that the entire range is visible after performing the scroll.
    ///
    /// - Parameters:
    ///   - range: The range of text to scroll into view.
    public func scrollRangeToVisible(_ range: NSRange) {
        textViewController.viewportScroller.scroll(toVisibleRange: range)
    }

    /// Replaces the text that is in the specified range.
    /// - Parameters:
    ///   - range: A range of text in the document.
    ///   - text: A string to replace the text in range.
    public func replace(_ range: NSRange, withText text: String) {
        textViewController.textReplacer.replaceText(in: range, with: text)
    }

    /// Returns the text in the specified range.
    /// - Parameter range: A range of text in the document.
    /// - Returns: The substring that falls within the specified range.
    public func text(in range: NSRange) -> String? {
        textViewController.stringView.value.substring(in: range)
    }
}

// MARK: - Scrolling
private extension TextView {
    private func setupScrollViewBoundsDidChangeObserver() {
        boundsObserver?.cancel()
        boundsObserver = nil
        guard let contentView = scrollView?.contentView else {
            return
        }
        boundsObserver = NotificationCenter.default
            .publisher(for: NSView.boundsDidChangeNotification, object: contentView)
            .sink { [weak self] _ in
                self?.updateViewport()
            }
    }

    private func updateViewport() {
        let viewport = textViewController.textContainer.viewport
        if let scrollView {
            viewport.value = scrollView.documentVisibleRect
        } else {
            viewport.value = CGRect(origin: .zero, size: frame.size)
        }
    }

    private func scrollToVisibleLocationIfNeeded() {
        let selectedRange = textViewController.selectedRange.value
        if isAutomaticScrollEnabled, selectedRange.length == 0 {
            let visibleRange = NSRange(location: selectedRange.location, length: 0)
            textViewController.viewportScroller.scroll(toVisibleRange: visibleRange)
        }
    }
}

// MARK: - Menu
private extension TextView {
    private func setupMenu() {
        menu = NSMenu()
        menu?.addItem(withTitle: L10n.Menu.ItemTitle.cut, action: #selector(cut(_:)), keyEquivalent: "")
        menu?.addItem(withTitle: L10n.Menu.ItemTitle.copy, action: #selector(copy(_:)), keyEquivalent: "")
        menu?.addItem(withTitle: L10n.Menu.ItemTitle.paste, action: #selector(paste(_:)), keyEquivalent: "")
    }
}

// MARK: - Find
private extension TextView {
    private func setupTextFinder() {
        textFinderClient.textView = self
        textFinder.client = textFinderClient
        textFinder.findBarContainer = scrollView
    }
}
#endif
