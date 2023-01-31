#if os(macOS)
import AppKit

public final class TextView: NSView {
    public weak var editorDelegate: TextViewDelegate?
    public override var acceptsFirstResponder: Bool {
        true
    }
    /// Whether the text view is in a state where the contents can be edited.
    public var isEditing: Bool {
        textViewController.isEditing
    }
    /// The text that the text view displays.
    public var text: String {
        get {
            return textViewController.text
        }
        set {
            textViewController.text = newValue
            scrollView.contentSize = textViewController.contentSize
        }
    }
    /// Colors and fonts to be used by the editor.
    public var theme: Theme {
        get {
            return textViewController.theme
        }
        set {
            textViewController.theme = newValue
        }
    }
    /// Character pairs are used by the editor to automatically insert a trailing character when the user types the leading character.
    ///
    /// Common usages of this includes the \" character to surround strings and { } to surround a scope.
    public var characterPairs: [CharacterPair] {
        get {
            return textViewController.characterPairs
        }
        set {
            textViewController.characterPairs = newValue
        }
    }
    /// Determines what should happen to the trailing component of a character pair when deleting the leading component. Defaults to `disabled` meaning that nothing will happen.
    public var characterPairTrailingComponentDeletionMode: CharacterPairTrailingComponentDeletionMode {
        get {
            return textViewController.characterPairTrailingComponentDeletionMode
        }
        set {
            textViewController.characterPairTrailingComponentDeletionMode = newValue
        }
    }
    /// Enable to show line numbers in the gutter.
    public var showLineNumbers: Bool {
        get {
            return textViewController.showLineNumbers
        }
        set {
            textViewController.showLineNumbers = newValue
        }
    }
    /// Enable to show highlight the selected lines. The selection is only shown in the gutter when multiple lines are selected.
    public var lineSelectionDisplayType: LineSelectionDisplayType {
        get {
            return textViewController.lineSelectionDisplayType
        }
        set {
            textViewController.lineSelectionDisplayType = newValue
        }
    }
    /// The text view renders invisible tabs when enabled. The `tabsSymbol` is used to render tabs.
    public var showTabs: Bool {
        get {
            return textViewController.showTabs
        }
        set {
            textViewController.showTabs = newValue
        }
    }
    /// The text view renders invisible spaces when enabled.
    ///
    /// The `spaceSymbol` is used to render spaces.
    public var showSpaces: Bool {
        get {
            return textViewController.showSpaces
        }
        set {
            textViewController.showSpaces = newValue
        }
    }
    /// The text view renders invisible spaces when enabled.
    ///
    /// The `nonBreakingSpaceSymbol` is used to render spaces.
    public var showNonBreakingSpaces: Bool {
        get {
            return textViewController.showNonBreakingSpaces
        }
        set {
            textViewController.showNonBreakingSpaces = newValue
        }
    }
    /// The text view renders invisible line breaks when enabled.
    ///
    /// The `lineBreakSymbol` is used to render line breaks.
    public var showLineBreaks: Bool {
        get {
            return textViewController.showLineBreaks
        }
        set {
            textViewController.showLineBreaks = newValue
        }
    }
    /// The text view renders invisible soft line breaks when enabled.
    ///
    /// The `softLineBreakSymbol` is used to render line breaks. These line breaks are typically represented by the U+2028 unicode character. Runestone does not provide any key commands for inserting these but supports rendering them.
    public var showSoftLineBreaks: Bool {
        get {
            return textViewController.showSoftLineBreaks
        }
        set {
            textViewController.showSoftLineBreaks = newValue
        }
    }
    /// Symbol used to display tabs.
    ///
    /// The value is only used when invisible tab characters is enabled. The default is ▸.
    ///
    /// Common characters for this symbol include ▸, ⇥, ➜, ➞, and ❯.
    public var tabSymbol: String {
        get {
            return textViewController.tabSymbol
        }
        set {
            textViewController.tabSymbol = newValue
        }
    }
    /// Symbol used to display spaces.
    ///
    /// The value is only used when showing invisible space characters is enabled. The default is ·.
    ///
    /// Common characters for this symbol include ·, •, and _.
    public var spaceSymbol: String {
        get {
            return textViewController.spaceSymbol
        }
        set {
            textViewController.spaceSymbol = newValue
        }
    }
    /// Symbol used to display non-breaking spaces.
    ///
    /// The value is only used when showing invisible space characters is enabled. The default is ·.
    ///
    /// Common characters for this symbol include ·, •, and _.
    public var nonBreakingSpaceSymbol: String {
        get {
            return textViewController.nonBreakingSpaceSymbol
        }
        set {
            textViewController.nonBreakingSpaceSymbol = newValue
        }
    }
    /// Symbol used to display line break.
    ///
    /// The value is only used when showing invisible line break characters is enabled. The default is ¬.
    ///
    /// Common characters for this symbol include ¬, ↵, ↲, ⤶, and ¶.
    public var lineBreakSymbol: String {
        get {
            return textViewController.lineBreakSymbol
        }
        set {
            textViewController.lineBreakSymbol = newValue
        }
    }
    /// Symbol used to display soft line breaks.
    ///
    /// The value is only used when showing invisible soft line break characters is enabled. The default is ¬.
    ///
    /// Common characters for this symbol include ¬, ↵, ↲, ⤶, and ¶.
    public var softLineBreakSymbol: String {
        get {
            return textViewController.softLineBreakSymbol
        }
        set {
            textViewController.softLineBreakSymbol = newValue
        }
    }
    /// The strategy used when indenting text.
    public var indentStrategy: IndentStrategy {
        get {
            return textViewController.indentStrategy
        }
        set {
            textViewController.indentStrategy = newValue
        }
    }
    /// The amount of padding before the line numbers inside the gutter.
    public var gutterLeadingPadding: CGFloat {
        get {
            return textViewController.gutterLeadingPadding
        }
        set {
            textViewController.gutterLeadingPadding = newValue
        }
    }
    /// The amount of padding after the line numbers inside the gutter.
    public var gutterTrailingPadding: CGFloat {
        get {
            return textViewController.gutterTrailingPadding
        }
        set {
            textViewController.gutterTrailingPadding = newValue
        }
    }
    /// The minimum amount of characters to use for width calculation inside the gutter.
    public var gutterMinimumCharacterCount: Int {
        get {
            return textViewController.gutterMinimumCharacterCount
        }
        set {
            textViewController.gutterMinimumCharacterCount = newValue
        }
    }
    /// The amount of spacing surrounding the lines.
    public var textContainerInset: NSEdgeInsets {
        get {
            return textViewController.textContainerInset
        }
        set {
            textViewController.textContainerInset = newValue
        }
    }
    /// When line wrapping is disabled, users can scroll the text view horizontally to see the entire line.
    ///
    /// Line wrapping is enabled by default.
    public var isLineWrappingEnabled: Bool {
        get {
            return textViewController.isLineWrappingEnabled
        }
        set {
            textViewController.isLineWrappingEnabled = newValue
        }
    }
    /// Line break mode for text view. The default value is .byWordWrapping meaning that wrapping occurs on word boundaries.
    public var lineBreakMode: LineBreakMode {
        get {
            return textViewController.lineBreakMode
        }
        set {
            textViewController.lineBreakMode = newValue
        }
    }
    /// Width of the gutter.
    public var gutterWidth: CGFloat {
        textViewController.gutterWidth
    }
    /// The line-height is multiplied with the value.
    public var lineHeightMultiplier: CGFloat {
        get {
            return textViewController.lineHeightMultiplier
        }
        set {
            textViewController.lineHeightMultiplier = newValue
        }
    }
    /// The number of points by which to adjust kern. The default value is 0 meaning that kerning is disabled.
    public var kern: CGFloat {
        get {
            return textViewController.kern
        }
        set {
            textViewController.kern = newValue
        }
    }
    /// The text view shows a page guide when enabled. Use `pageGuideColumn` to specify the location of the page guide.
    public var showPageGuide: Bool {
        get {
            return textViewController.showPageGuide
        }
        set {
            textViewController.showPageGuide = newValue
        }
    }
    /// Specifies the location of the page guide. Use `showPageGuide` to specify if the page guide should be shown.
    public var pageGuideColumn: Int {
        get {
            return textViewController.pageGuideColumn
        }
        set {
            textViewController.pageGuideColumn = newValue
        }
    }
    /// Automatically scrolls the text view to show the caret when typing or moving the caret.
    public var isAutomaticScrollEnabled: Bool {
        get {
            return textViewController.isAutomaticScrollEnabled
        }
        set {
            textViewController.isAutomaticScrollEnabled = newValue
        }
    }
    /// Amount of overscroll to add in the vertical direction.
    ///
    /// The overscroll is a factor of the scrollable area height and will not take into account any insets. 0 means no overscroll and 1 means an amount equal to the height of the text view. Detaults to 0.
    public var verticalOverscrollFactor: CGFloat {
        get {
            return textViewController.verticalOverscrollFactor
        }
        set {
            textViewController.verticalOverscrollFactor = newValue
        }
    }
    /// Amount of overscroll to add in the horizontal direction.
    ///
    /// The overscroll is a factor of the scrollable area height and will not take into account any insets or the width of the gutter. 0 means no overscroll and 1 means an amount equal to the width of the text view. Detaults to 0.
    public var horizontalOverscrollFactor: CGFloat {
        get {
            return textViewController.horizontalOverscrollFactor
        }
        set {
            textViewController.horizontalOverscrollFactor = newValue
        }
    }
    /// The length of the line that was longest when opening the document.
    ///
    /// This will return nil if the line is no longer available. The value will not be kept updated as the text is changed. The value can be used to determine if a document contains a very long line in which case the performance may be degraded when editing the line.
    public var lengthOfInitallyLongestLine: Int? {
        textViewController.lengthOfInitallyLongestLine
    }
    /// Ranges in the text to be highlighted. The color defined by the background will be drawen behind the text.
    public var highlightedRanges: [HighlightedRange] {
        get {
            return textViewController.highlightedRanges
        }
        set {
            textViewController.highlightedRanges = newValue
        }
    }
    /// Wheter the text view should loop when navigating through highlighted ranges using `selectPreviousHighlightedRange` or `selectNextHighlightedRange` on the text view.
    public var highlightedRangeLoopingMode: HighlightedRangeLoopingMode {
        get {
            return textViewController.highlightedRangeLoopingMode
        }
        set {
            textViewController.highlightedRangeLoopingMode = newValue
        }
    }
    /// Line endings to use when inserting a line break.
    ///
    /// The value only affects new line breaks inserted in the text view and changing this value does not change the line endings of the text in the text view. Defaults to Unix (LF).
    ///
    /// The TextView will only update the line endings when text is modified through an external event, such as when the user typing on the keyboard, when the user is replacing selected text, and when pasting text into the text view. In all other cases, you should make sure that the text provided to the text view uses the desired line endings. This includes when calling ``TextView/setState(_:addUndoAction:)`` and ``TextView/replaceText(in:)``.
    public var lineEndings: LineEnding {
        get {
            return textViewController.lineEndings
        }
        set {
            textViewController.lineEndings = newValue
        }
    }

    private(set) lazy var textViewController = TextViewController(
        textView: self,
        scrollView: scrollView,
        scrollContentView: scrollContentView
    )

    public override var isFlipped: Bool {
        true
    }

    private let scrollView = NSScrollView()
    private let scrollContentView = FlippedView()
    private let caretView = CaretView()
    private var isWindowKey = false {
        didSet {
            if isWindowKey != oldValue {
                updateCaretVisibility()
            }
        }
    }
    private var isFirstResponder = false {
        didSet {
            if isFirstResponder != oldValue {
                updateCaretVisibility()
            }
        }
    }

    public init() {
        super.init(frame: .zero)
        textViewController.delegate = self
        textViewController.selectedRange = NSRange(location: 0, length: 0)
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.documentView = scrollContentView
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollContentView.addSubview(caretView)
        addSubview(scrollView)
        setNeedsLayout()
        setupWindowObservers()
        setupScrollViewBoundsDidChangeObserver()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @discardableResult
    public override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            isFirstResponder = true
        }
        return result
    }

    @discardableResult
    public override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result {
            isFirstResponder = false
        }
        return result
    }

    public override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        scrollView.frame = bounds
        textViewController.viewport = CGRect(origin: scrollView.contentOffset, size: frame.size)
        textViewController.scrollViewWidth = scrollView.frame.width
        textViewController.layoutIfNeeded()
        textViewController.handleContentSizeUpdateIfNeeded()
        updateCaretFrame()
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        textViewController.performFullLayoutIfNeeded()
    }

    public override func keyDown(with event: NSEvent) {
        NSCursor.setHiddenUntilMouseMoves(true)
        let didInputContextHandleEvent = inputContext?.handleEvent(event) ?? false
        if !didInputContextHandleEvent {
            super.keyDown(with: event)
        }
    }
}

// MARK: - Commands
public extension TextView {
    override func deleteBackward(_ sender: Any?) {
        guard var selectedRange = textViewController.markedRange ?? textViewController.selectedRange else {
            return
        }
        if selectedRange.length == 0 {
            selectedRange.location -= 1
            selectedRange.length = 1
        }
        let deleteRange = textViewController.rangeForDeletingText(in: selectedRange)
        // If we're deleting everything in the marked range then we clear the marked range. UITextInput doesn't do that for us.
        // Can be tested by entering a backtick (`) in an empty document and deleting it.
        if deleteRange == textViewController.markedRange {
            textViewController.markedRange = nil
        }
        guard textViewController.shouldChangeText(in: deleteRange, replacementText: "") else {
            return
        }
        let isDeletingMultipleCharacters = selectedRange.length > 1
        if isDeletingMultipleCharacters {
            undoManager?.endUndoGrouping()
            undoManager?.beginUndoGrouping()
        }
        textViewController.replaceText(in: deleteRange, with: "", selectedRangeAfterUndo: selectedRange)
        if isDeletingMultipleCharacters {
            undoManager?.endUndoGrouping()
        }
    }

    override func insertNewline(_ sender: Any?) {
        textViewController.indentController.insertLineBreak(in: textViewController.rangeForInsertingText, using: lineEndings)
    }

    override func moveLeft(_ sender: Any?) {
        textViewController.moveLeft()
    }

    override func moveRight(_ sender: Any?) {
        textViewController.moveRight()
    }

    override func moveUp(_ sender: Any?) {
        textViewController.moveUp()
    }

    override func moveDown(_ sender: Any?) {
        textViewController.moveDown()
    }

    override func moveForward(_ sender: Any?) {
        textViewController.moveRight()
    }

    override func moveBackward(_ sender: Any?) {
        textViewController.moveLeft()
    }

    override func moveWordLeft(_ sender: Any?) {
        textViewController.moveWordLeft()
    }

    override func moveWordRight(_ sender: Any?) {
        textViewController.moveWordRight()
    }

    override func moveToBeginningOfLine(_ sender: Any?) {
        textViewController.moveToBeginningOfLine()
    }

    override func moveToEndOfLine(_ sender: Any?) {
        textViewController.moveToEndOfLine()
    }

    override func moveToBeginningOfParagraph(_ sender: Any?) {
        textViewController.moveToBeginningOfParagraph()
    }

    override func moveToEndOfParagraph(_ sender: Any?) {
        textViewController.moveToEndOfParagraph()
    }

    override func moveToBeginningOfDocument(_ sender: Any?) {
        textViewController.moveToBeginningOfDocument()
    }

    override func moveToEndOfDocument(_ sender: Any?) {
        textViewController.moveToEndOfDocument()
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        textViewController.moveToLocation(closestTo: point)
    }
}

// MARK: - Window
private extension TextView {
    private func setupWindowObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowKeyStateDidChange),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowKeyStateDidChange),
            name: NSWindow.didResignKeyNotification,
            object: nil
        )
    }

    @objc private func windowKeyStateDidChange() {
        isWindowKey = window?.isKeyWindow ?? false
    }
}

// MARK: - Scroll Bounds
private extension TextView {
    private func setupScrollViewBoundsDidChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(scrollViewBoundsDidChange),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    @objc private func scrollViewBoundsDidChange() {
        textViewController.viewport = CGRect(origin: scrollView.contentOffset, size: frame.size)
        textViewController.layoutIfNeeded()
        print(textViewController.viewport)
    }
}

// MARK: - Caret
private extension TextView {
    private func updateCaretFrame() {
        let selectedRange = selectedRange()
        let caretRect = textViewController.caretRectService.caretRect(at: selectedRange.upperBound, allowMovingCaretToNextLineFragment: true)
        caretView.frame = caretRect
    }

    private func updateCaretVisibility() {
        if isWindowKey && isFirstResponder {
            caretView.isHidden = false
            caretView.isBlinkingEnabled = true
            caretView.delayBlinkIfNeeded()
        } else {
            caretView.isHidden = true
            caretView.isBlinkingEnabled = false
        }
    }
}

// MARK: - TextViewControllerDelegate
extension TextView: TextViewControllerDelegate {
    func textViewControllerDidChangeText(_ textViewController: TextViewController) {
        caretView.delayBlinkIfNeeded()
        updateCaretFrame()
    }

    func textViewController(_ textViewController: TextViewController, didUpdateSelectedRange selectedRange: NSRange?) {
        caretView.delayBlinkIfNeeded()
        updateCaretFrame()
    }
}
#endif
