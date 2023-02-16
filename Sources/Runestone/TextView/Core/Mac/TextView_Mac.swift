// swiftlint:disable file_length
#if os(macOS)
import AppKit
import UniformTypeIdentifiers

// swiftlint:disable:next type_body_length
open class TextView: NSView, NSMenuItemValidation {
    public weak var editorDelegate: TextViewDelegate?
    override public var acceptsFirstResponder: Bool {
        true
    }
    override public var isFlipped: Bool {
        true
    }
    /// A Boolean value that indicates whether the text view is editable.
    public var isEditable: Bool {
        get {
            textViewController.isEditable
        }
        set {
            if newValue != isEditable {
                textViewController.isEditable = newValue
            }
        }
    }
    /// Whether the text view is in a state where the contents can be edited.
    public var isEditing: Bool {
        textViewController.isEditing
    }
    /// The text that the text view displays.
    public var text: String {
        get {
            textViewController.text
        }
        set {
            textViewController.text = newValue
        }
    }
    /// Colors and fonts to be used by the editor.
    public var theme: Theme {
        get {
            textViewController.theme
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
            textViewController.characterPairs
        }
        set {
            textViewController.characterPairs = newValue
        }
    }
    /// Determines what should happen to the trailing component of a character pair when deleting the leading component. Defaults to `disabled` meaning that nothing will happen.
    public var characterPairTrailingComponentDeletionMode: CharacterPairTrailingComponentDeletionMode {
        get {
            textViewController.characterPairTrailingComponentDeletionMode
        }
        set {
            textViewController.characterPairTrailingComponentDeletionMode = newValue
        }
    }
    /// Enable to show line numbers in the gutter.
    public var showLineNumbers: Bool {
        get {
            textViewController.showLineNumbers
        }
        set {
            textViewController.showLineNumbers = newValue
        }
    }
    /// Enable to show highlight the selected lines. The selection is only shown in the gutter when multiple lines are selected.
    public var lineSelectionDisplayType: LineSelectionDisplayType {
        get {
            textViewController.lineSelectionDisplayType
        }
        set {
            textViewController.lineSelectionDisplayType = newValue
        }
    }
    /// The text view renders invisible tabs when enabled. The `tabsSymbol` is used to render tabs.
    public var showTabs: Bool {
        get {
            textViewController.showTabs
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
            textViewController.showSpaces
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
            textViewController.showNonBreakingSpaces
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
            textViewController.showLineBreaks
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
            textViewController.showSoftLineBreaks
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
            textViewController.tabSymbol
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
            textViewController.spaceSymbol
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
            textViewController.nonBreakingSpaceSymbol
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
            textViewController.lineBreakSymbol
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
            textViewController.softLineBreakSymbol
        }
        set {
            textViewController.softLineBreakSymbol = newValue
        }
    }
    /// The strategy used when indenting text.
    public var indentStrategy: IndentStrategy {
        get {
            textViewController.indentStrategy
        }
        set {
            textViewController.indentStrategy = newValue
        }
    }
    /// The amount of padding before the line numbers inside the gutter.
    public var gutterLeadingPadding: CGFloat {
        get {
            textViewController.gutterLeadingPadding
        }
        set {
            textViewController.gutterLeadingPadding = newValue
        }
    }
    /// The amount of padding after the line numbers inside the gutter.
    public var gutterTrailingPadding: CGFloat {
        get {
            textViewController.gutterTrailingPadding
        }
        set {
            textViewController.gutterTrailingPadding = newValue
        }
    }
    /// The minimum amount of characters to use for width calculation inside the gutter.
    public var gutterMinimumCharacterCount: Int {
        get {
            textViewController.gutterMinimumCharacterCount
        }
        set {
            textViewController.gutterMinimumCharacterCount = newValue
        }
    }
    /// The amount of spacing surrounding the lines.
    public var textContainerInset: NSEdgeInsets {
        get {
            textViewController.textContainerInset
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
            textViewController.isLineWrappingEnabled
        }
        set {
            textViewController.isLineWrappingEnabled = newValue
        }
    }
    /// Line break mode for text view. The default value is .byWordWrapping meaning that wrapping occurs on word boundaries.
    public var lineBreakMode: LineBreakMode {
        get {
            textViewController.lineBreakMode
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
            textViewController.lineHeightMultiplier
        }
        set {
            textViewController.lineHeightMultiplier = newValue
        }
    }
    /// The number of points by which to adjust kern. The default value is 0 meaning that kerning is disabled.
    public var kern: CGFloat {
        get {
            textViewController.kern
        }
        set {
            textViewController.kern = newValue
        }
    }
    /// The text view shows a page guide when enabled. Use `pageGuideColumn` to specify the location of the page guide.
    public var showPageGuide: Bool {
        get {
            textViewController.showPageGuide
        }
        set {
            textViewController.showPageGuide = newValue
        }
    }
    /// Specifies the location of the page guide. Use `showPageGuide` to specify if the page guide should be shown.
    public var pageGuideColumn: Int {
        get {
            textViewController.pageGuideColumn
        }
        set {
            textViewController.pageGuideColumn = newValue
        }
    }
    /// Automatically scrolls the text view to show the caret when typing or moving the caret.
    public var isAutomaticScrollEnabled: Bool {
        get {
            textViewController.isAutomaticScrollEnabled
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
            textViewController.verticalOverscrollFactor
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
            textViewController.horizontalOverscrollFactor
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
            textViewController.highlightedRanges
        }
        set {
            textViewController.highlightedRanges = newValue
        }
    }
    /// Wheter the text view should loop when navigating through highlighted ranges using `selectPreviousHighlightedRange` or `selectNextHighlightedRange` on the text view.
    public var highlightedRangeLoopingMode: HighlightedRangeLoopingMode {
        get {
            textViewController.highlightedRangeLoopingMode
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
            textViewController.lineEndings
        }
        set {
            textViewController.lineEndings = newValue
        }
    }
    /// The color of the insertion point. This can be used to control the color of the caret.
    public var insertionPointColor: NSColor = .label {
        didSet {
            if insertionPointColor != oldValue {
                caretView.color = insertionPointColor
            }
        }
    }
    /// The color of the selection highlight. It is most common to set this to the same color as the color used for the insertion point.
    public var selectionHighlightColor: NSColor = .label.withAlphaComponent(0.2) {
        didSet {
            if selectionHighlightColor != oldValue {
                for (_, view) in selectionViewReuseQueue.visibleViews {
                    view.backgroundColor = selectionHighlightColor
                }
            }
        }
    }
    override open var undoManager: UndoManager? {
        textViewController.timedUndoManager
    }

    private(set) lazy var textViewController = TextViewController(textView: self, scrollView: scrollView)

    private let scrollView = NSScrollView()
    private let scrollContentView = FlippedView()
    private let caretView = CaretView()
    private let selectionViewReuseQueue = ViewReuseQueue<String, LineSelectionView>()
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

    public init() {
        super.init(frame: .zero)
        textViewController.delegate = self
        textViewController.selectedRange = NSRange(location: 0, length: 0)
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.documentView = scrollContentView
        scrollView.contentView.postsBoundsChangedNotifications = true
        scrollContentView.addSubview(textViewController.layoutManager.linesContainerView)
        scrollContentView.addSubview(caretView)
        scrollView.addSubview(textViewController.layoutManager.gutterContainerView)
        addSubview(textViewController.layoutManager.lineSelectionBackgroundView)
        addSubview(scrollView)
        setNeedsLayout()
        setupWindowObservers()
        setupScrollViewBoundsDidChangeObserver()
        setupMenu()
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @discardableResult
    override open func becomeFirstResponder() -> Bool {
        guard !isEditing && shouldBeginEditing else {
            return false
        }
        let didBecomeFirstResponder = super.becomeFirstResponder()
        if didBecomeFirstResponder {
            isFirstResponder = true
            textViewController.isEditing = true
            editorDelegate?.textViewDidBeginEditing(self)
        } else {
            textViewController.isEditing = false
        }
        return didBecomeFirstResponder
    }

    @discardableResult
    override open func resignFirstResponder() -> Bool {
        guard isEditing && shouldEndEditing else {
            return false
        }
        let didResignFirstResponder = super.resignFirstResponder()
        if didResignFirstResponder {
            isFirstResponder = false
            textViewController.isEditing = false
            editorDelegate?.textViewDidEndEditing(self)
        }
        return didResignFirstResponder
    }

    override public func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        scrollView.frame = bounds
        textViewController.viewport = CGRect(origin: scrollView.contentOffset, size: frame.size)
        textViewController.scrollViewSize = scrollView.frame.size
        textViewController.layoutIfNeeded()
        textViewController.handleContentSizeUpdateIfNeeded()
        updateCaretFrame()
        updateSelectedRectangles()
    }

    override public func layoutSubtreeIfNeeded() {
        super.layoutSubtreeIfNeeded()
        textViewController.layoutIfNeeded()
    }

    override public func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        textViewController.performFullLayoutIfNeeded()
    }

    override public func keyDown(with event: NSEvent) {
        NSCursor.setHiddenUntilMouseMoves(true)
        let didInputContextHandleEvent = inputContext?.handleEvent(event) ?? false
        if !didInputContextHandleEvent {
            super.keyDown(with: event)
        }
    }

    override public func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        if event.clickCount == 1, let location = locationClosestToPoint(in: event) {
            textViewController.move(to: location)
            textViewController.startDraggingSelection(from: location)
        } else if event.clickCount == 2, let location = locationClosestToPoint(in: event) {
            textViewController.selectWord(at: location)
        } else if event.clickCount == 3, let location = locationClosestToPoint(in: event) {
            textViewController.selectLine(at: location)
        }
    }

    override public func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        if let location = locationClosestToPoint(in: event) {
            textViewController.extendDraggedSelection(to: location)
        }
    }

    override public func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if event.clickCount == 1, let location = locationClosestToPoint(in: event) {
            textViewController.extendDraggedSelection(to: location)
        }
    }

    override public func rightMouseDown(with event: NSEvent) {
        if event.clickCount == 1, let location = locationClosestToPoint(in: event) {
            if let selectedRange = textViewController.selectedRange, !selectedRange.contains(location) || textViewController.selectedRange == nil {
                textViewController.selectWord(at: location)
            }
        }
        super.rightMouseDown(with: event)
    }

    override public func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .iBeam)
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
        textViewController.setState(state, addUndoAction: addUndoAction)
    }

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
}

// MARK: - Commands
public extension TextView {
    override func deleteBackward(_ sender: Any?) {
        guard var selectedRange = textViewController.markedRange ?? textViewController.selectedRange?.nonNegativeLength else {
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
        if textViewController.shouldChangeText(in: textViewController.rangeForInsertingText, replacementText: lineEndings.symbol) {
            textViewController.indentController.insertLineBreak(in: textViewController.rangeForInsertingText, using: lineEndings.symbol)
        }
    }

    override func insertTab(_ sender: Any?) {
        let indentString = indentStrategy.string(indentLevel: 1)
        if textViewController.shouldChangeText(in: textViewController.rangeForInsertingText, replacementText: indentString) {
            textViewController.replaceText(in: textViewController.rangeForInsertingText, with: indentString)
        }
    }

    override func moveLeft(_ sender: Any?) {
        textViewController.moveLeft()
    }

    override func moveRight(_ sender: Any?) {
        textViewController.moveRight()
    }

    override func moveForward(_ sender: Any?) {
        textViewController.moveRight()
    }

    override func moveBackward(_ sender: Any?) {
        textViewController.moveLeft()
    }

    override func moveUp(_ sender: Any?) {
        textViewController.moveUp()
    }

    override func moveDown(_ sender: Any?) {
        textViewController.moveDown()
    }

    override func moveWordLeft(_ sender: Any?) {
        textViewController.moveWordLeft()
    }

    override func moveWordRight(_ sender: Any?) {
        textViewController.moveWordRight()
    }

    override func moveWordForward(_ sender: Any?) {
        textViewController.moveWordRight()
    }

    override func moveWordBackward(_ sender: Any?) {
        textViewController.moveWordLeft()
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

    override func moveLeftAndModifySelection(_ sender: Any?) {
        textViewController.moveLeftAndModifySelection()
    }

    override func moveRightAndModifySelection(_ sender: Any?) {
        textViewController.moveRightAndModifySelection()
    }

    override func moveForwardAndModifySelection(_ sender: Any?) {
        textViewController.moveRightAndModifySelection()
    }

    override func moveBackwardAndModifySelection(_ sender: Any?) {
        textViewController.moveLeftAndModifySelection()
    }

    override func moveUpAndModifySelection(_ sender: Any?) {
        textViewController.moveUpAndModifySelection()
    }

    override func moveDownAndModifySelection(_ sender: Any?) {
        textViewController.moveDownAndModifySelection()
    }

    override func moveWordLeftAndModifySelection(_ sender: Any?) {
        textViewController.moveWordLeftAndModifySelection()
    }

    override func moveWordRightAndModifySelection(_ sender: Any?) {
        textViewController.moveWordRightAndModifySelection()
    }

    override func moveWordBackwardAndModifySelection(_ sender: Any?) {
        textViewController.moveWordLeftAndModifySelection()
    }

    override func moveWordForwardAndModifySelection(_ sender: Any?) {
        textViewController.moveWordRightAndModifySelection()
    }

    override func moveToBeginningOfLineAndModifySelection(_ sender: Any?) {
        textViewController.moveToBeginningOfLineAndModifySelection()
    }

    override func moveToEndOfLineAndModifySelection(_ sender: Any?) {
        textViewController.moveToEndOfLineAndModifySelection()
    }

    override func moveToBeginningOfParagraphAndModifySelection(_ sender: Any?) {
        textViewController.moveToBeginningOfParagraphAndModifySelection()
    }

    override func moveToEndOfParagraphAndModifySelection(_ sender: Any?) {
        textViewController.moveToEndOfParagraphAndModifySelection()
    }

    override func moveToBeginningOfDocumentAndModifySelection(_ sender: Any?) {
        textViewController.moveToBeginningOfDocumentAndModifySelection()
    }

    override func moveToEndOfDocumentAndModifySelection(_ sender: Any?) {
        textViewController.moveToEndOfDocumentAndModifySelection()
    }

    /// Copy the selected text.
    ///
    /// - Parameter sender: The object calling this method.
    @objc func copy(_ sender: Any?) {
        let selectedRange = selectedRange()
        if selectedRange.length > 0, let text = textViewController.text(in: selectedRange) {
            NSPasteboard.general.declareTypes([.string], owner: nil)
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    /// Paste text from the pasteboard.
    ///
    /// - Parameter sender: The object calling this method.
    @objc func paste(_ sender: Any?) {
        let selectedRange = selectedRange()
        if let string = NSPasteboard.general.string(forType: .string) {
            let preparedText = textViewController.prepareTextForInsertion(string)
            textViewController.replaceText(in: selectedRange, with: preparedText)
        }
    }

    /// Cut text  to the pasteboard.
    ///
    /// - Parameter sender: The object calling this method.
    @objc func cut(_ sender: Any?) {
        let selectedRange = selectedRange()
        if selectedRange.length > 0, let text = textViewController.text(in: selectedRange) {
            NSPasteboard.general.setString(text, forType: .string)
            textViewController.replaceText(in: selectedRange, with: "")
        }
    }

    /// Select all text in the text view.
    ///
    /// - Parameter sender: The object calling this method.
    override func selectAll(_ sender: Any?) {
        textViewController.selectedRange = NSRange(location: 0, length: textViewController.stringView.string.length)
    }

    @objc func undo(_ sender: Any?) {
        if let undoManager = undoManager, undoManager.canUndo {
            undoManager.undo()
        }
    }

    @objc func redo(_ sender: Any?) {
        if let undoManager = undoManager, undoManager.canRedo {
            undoManager.redo()
        }
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

// MARK: - Scrolling
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
    }

    private func scrollToVisibleLocationIfNeeded() {
        if isAutomaticScrollEnabled, let newRange = textViewController.selectedRange, newRange.length == 0 {
            textViewController.scrollLocationToVisible(newRange.location)
        }
    }
}

// MARK: - Caret
private extension TextView {
    private func updateCaretFrame() {
        let caretRectFactory = CaretRectFactory(
            stringView: textViewController.stringView,
            lineManager: textViewController.lineManager,
            lineControllerStorage: textViewController.lineControllerStorage,
            gutterWidthService: textViewController.gutterWidthService,
            textContainerInset: textContainerInset
        )
        let selectedRange = selectedRange()
        caretView.frame = caretRectFactory.caretRect(at: selectedRange.upperBound, allowMovingCaretToNextLineFragment: true)
    }

    private func updateCaretVisibility() {
        if isWindowKey && isFirstResponder && selectedRange().length == 0 {
            caretView.isHidden = false
            caretView.isBlinkingEnabled = true
            caretView.delayBlinkIfNeeded()
        } else {
            caretView.isHidden = true
            caretView.isBlinkingEnabled = false
        }
    }
}

// MARK: - Selection
private extension TextView {
    private func updateSelectedRectangles() {
        let selectedRange = selectedRange()
        guard selectedRange.length != 0 else {
            removeAllLineSelectionViews()
            return
        }
        let caretRectFactory = CaretRectFactory(
            stringView: textViewController.stringView,
            lineManager: textViewController.lineManager,
            lineControllerStorage: textViewController.lineControllerStorage,
            gutterWidthService: textViewController.gutterWidthService,
            textContainerInset: textContainerInset
        )
        let selectionRectFactory = SelectionRectFactory(
            lineManager: textViewController.lineManager,
            gutterWidthService: textViewController.gutterWidthService,
            contentSizeService: textViewController.contentSizeService,
            caretRectFactory: caretRectFactory,
            textContainerInset: textContainerInset,
            lineHeightMultiplier: lineHeightMultiplier
        )
        let selectionRects = selectionRectFactory.selectionRects(in: selectedRange)
        addLineSelectionViews(for: selectionRects)
    }

    private func removeAllLineSelectionViews() {
        for (_, view) in selectionViewReuseQueue.visibleViews {
            view.removeFromSuperview()
        }
        let keys = Set(selectionViewReuseQueue.visibleViews.keys)
        selectionViewReuseQueue.enqueueViews(withKeys: keys)
    }

    private func addLineSelectionViews(for selectionRects: [TextSelectionRect]) {
        var appearedViewKeys = Set<String>()
        for (idx, selectionRect) in selectionRects.enumerated() {
            let key = String(describing: idx)
            let view = selectionViewReuseQueue.dequeueView(forKey: key)
            view.frame = selectionRect.rect
            view.wantsLayer = true
            view.backgroundColor = selectionHighlightColor
            scrollContentView.addSubview(view)
            appearedViewKeys.insert(key)
        }
        let disappearedViewKeys = Set(selectionViewReuseQueue.visibleViews.keys).subtracting(appearedViewKeys)
        selectionViewReuseQueue.enqueueViews(withKeys: disappearedViewKeys)
    }
}

// MARK: - Location
private extension TextView {
    private func locationClosestToPoint(in event: NSEvent) -> Int? {
        let point = scrollContentView.convert(event.locationInWindow, from: nil)
        let adjustedPoint = CGPoint(x: point.x - gutterWidth - textContainerInset.left, y: point.y)
        return textViewController.layoutManager.closestIndex(to: adjustedPoint)
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

// MARK: - TextViewControllerDelegate
extension TextView: TextViewControllerDelegate {
    func textViewControllerDidChangeText(_ textViewController: TextViewController) {
        caretView.delayBlinkIfNeeded()
        updateCaretFrame()
    }

    func textViewController(_ textViewController: TextViewController, didChangeSelectedRange selectedRange: NSRange?) {
        layoutIfNeeded()
        caretView.delayBlinkIfNeeded()
        updateCaretVisibility()
        updateCaretFrame()
        updateSelectedRectangles()
        scrollToVisibleLocationIfNeeded()
    }
}
#endif
