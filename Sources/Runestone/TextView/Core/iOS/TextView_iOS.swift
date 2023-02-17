#if os(iOS)
// swiftlint:disable file_length type_body_length
import CoreText
import UIKit

/// A type similiar to UITextView with features commonly found in code editors.
///
/// `TextView` is a performant implementation of a text view with features such as showing line numbers, searching for text and replacing results, syntax highlighting, showing invisible characters and more.
///
/// The type does not subclass `UITextView` but its interface is kept close to `UITextView`.
///
/// When initially configuring the `TextView` with a theme, a language and the text to be shown, it is recommended to use the ``setState(_:addUndoAction:)`` function.
/// The function takes an instance of ``TextViewState`` as input which can be created on a background queue to avoid blocking the main queue while doing the initial parse of a text.
open class TextView: UIScrollView {
    /// An input delegate that receives a notification when text changes or when the selection changes.
    @objc public weak var inputDelegate: UITextInputDelegate?
    /// Returns a Boolean value indicating whether this object can become the first responder.
    override public var canBecomeFirstResponder: Bool {
        !isFirstResponder && isEditable
    }
    /// Delegate to receive callbacks for events triggered by the editor.
    public weak var editorDelegate: TextViewDelegate?
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
    /// A Boolean value that indicates whether the text view is editable.
    public var isEditable: Bool {
        get {
            textViewController.isEditable
        }
        set {
            if newValue != isEditable {
                textViewController.isEditable = newValue
                if !newValue {
                    installNonEditableInteraction()
                }
            }
        }
    }
    /// A Boolean value that indicates whether the text view is selectable.
    public var isSelectable: Bool {
        get {
            textViewController.isSelectable
        }
        set {
            if newValue != isSelectable {
                textViewController.isSelectable = newValue
                if !newValue {
                    installNonEditableInteraction()
                }
            }
        }
    }
    /// The current selection range of the text view.
    public var selectedRange: NSRange {
        get {
            if let selectedRange = textViewController.selectedRange {
                return selectedRange
            } else {
                // UITextView returns the end of the document for the selectedRange by default.
                return NSRange(location: textViewController.stringView.string.length, length: 0)
            }
        }
        set {
            if newValue != textViewController.selectedRange {
                textViewController.selectedRange = newValue
            }
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
    /// The autocorrection style for the text view.
    public var autocorrectionType: UITextAutocorrectionType = .default
    /// The autocapitalization style for the text view.
    public var autocapitalizationType: UITextAutocapitalizationType = .sentences
    /// The spell-checking style for the text view.
    public var smartQuotesType: UITextSmartQuotesType = .default
    /// The configuration state for smart dashes.
    public var smartDashesType: UITextSmartDashesType = .default
    /// The configuration state for the smart insertion and deletion of space characters.
    public var smartInsertDeleteType: UITextSmartInsertDeleteType = .default
    /// The spell-checking style for the text object.
    public var spellCheckingType: UITextSpellCheckingType = .default
    /// The keyboard type for the text view.
    public var keyboardType: UIKeyboardType = .default
    /// The appearance style of the keyboard for the text view.
    public var keyboardAppearance: UIKeyboardAppearance = .default
    /// The display of the return key.
    public var returnKeyType: UIReturnKeyType = .default
    /// Returns the undo manager used by the text view.
    override public var undoManager: UndoManager? {
        textViewController.timedUndoManager
    }
    /// The color of the insertion point. This can be used to control the color of the caret.
    @objc public var insertionPointColor: UIColor = .label {
        didSet {
            if insertionPointColor != oldValue {
                updateCaretColor()
            }
        }
    }
    /// The color of the selection bar. It is most common to set this to the same color as the color used for the insertion point.
    @objc public var selectionBarColor: UIColor = .label {
        didSet {
            if selectionBarColor != oldValue {
                updateCaretColor()
            }
        }
    }
    /// The color of the selection highlight. It is most common to set this to the same color as the color used for the insertion point.
    @objc public var selectionHighlightColor: UIColor = .label.withAlphaComponent(0.2) {
        didSet {
            if selectionHighlightColor != oldValue {
                updateCaretColor()
            }
        }
    }
    /// The point at which the origin of the content view is offset from the origin of the scroll view.
    override public var contentOffset: CGPoint {
        didSet {
            if contentOffset != oldValue {
                textViewController.viewport = CGRect(origin: contentOffset, size: frame.size)
            }
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
    public var textContainerInset: UIEdgeInsets {
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
    /// When enabled the text view will present a menu with actions actions such as Copy and Replace after navigating to a highlighted range.
    public var showMenuAfterNavigatingToHighlightedRange = true
    /// A boolean value that enables a text view's built-in find interaction.
    ///
    /// After enabling the find interaction, use [`presentFindNavigator(showingReplace:)`](https://developer.apple.com/documentation/uikit/uifindinteraction/3975832-presentfindnavigator) on <doc:findInteraction> to present the find navigator.
    @available(iOS 16, *)
    public var isFindInteractionEnabled: Bool {
        get {
            textSearchingHelper.isFindInteractionEnabled
        }
        set {
            textSearchingHelper.isFindInteractionEnabled = newValue
        }
    }
    /// The text view's built-in find interaction.
    ///
    /// Set <doc:isFindInteractionEnabled> to true to enable the text view's built-in find interaction. This method returns nil when the interaction isn't enabled.
    ///
    /// Call [`presentFindNavigator(showingReplace:)`](https://developer.apple.com/documentation/uikit/uifindinteraction/3975832-presentfindnavigator) on the UIFindInteraction object to invoke the find interaction and display the find panel.
    @available(iOS 16, *)
    public var findInteraction: UIFindInteraction? {
        textSearchingHelper.findInteraction
    }
    /// The custom input accessory view to display when the receiver becomes the first responder.
    override public var inputAccessoryView: UIView? {
        get {
            if isInputAccessoryViewEnabled {
                return _inputAccessoryView
            } else {
                return nil
            }
        }
        set {
            _inputAccessoryView = newValue
        }
    }

    private(set) lazy var textViewController = TextViewController(textView: self, scrollView: self)
    private(set) lazy var customTokenizer = TextInputStringTokenizer(
        textInput: self,
        stringView: textViewController.stringView,
        lineManager: textViewController.lineManager,
        lineControllerStorage: textViewController.lineControllerStorage
    )

    var isRestoringPreviouslyDeletedText = false
    var hasDeletedTextWithPendingLayoutSubviews = false
    var notifyInputDelegateAboutSelectionChangeInLayoutSubviews = false
    var notifyDelegateAboutSelectionChangeInLayoutSubviews = false
    var didCallPositionFromPositionInDirectionWithOffset = false

    private let editableTextInteraction = UITextInteraction(for: .editable)
    private let nonEditableTextInteraction = UITextInteraction(for: .nonEditable)
    private let textSearchingHelper = UITextSearchingHelper()
    private let editMenuController = EditMenuController()
    private let keyboardObserver = KeyboardObserver()
    private var isInputAccessoryViewEnabled = false
    private var _inputAccessoryView: UIView?
    private let tapGestureRecognizer = QuickTapGestureRecognizer()
    var floatingCaretView: FloatingCaretView?
    var insertionPointColorBeforeFloatingBegan: UIColor = .label
    // Store a reference to instances of the private type UITextRangeAdjustmentGestureRecognizer in order to track adjustments
    // to the selected text range and scroll the text view when the handles approach the bottom.
    // The approach is based on the one described in Steve Shephard's blog post "Adventures with UITextInteraction".
    // https://steveshepard.com/blog/adventures-with-uitextinteraction/
    private var textRangeAdjustmentGestureRecognizers: Set<UIGestureRecognizer> = []
    private var previousSelectedRangeDuringGestureHandling: NSRange?
    private var isPerformingNonEditableTextInteraction = false
    private var shouldBeginEditing: Bool {
        guard isEditable else {
            return false
        }
        return editorDelegate?.textViewShouldBeginEditing(self) ?? true
    }
    private var shouldEndEditing: Bool {
        editorDelegate?.textViewShouldEndEditing(self) ?? true
    }

    /// Create a new text view.
    /// - Parameter frame: The frame rectangle of the text view.
    override public init(frame: CGRect) {
        super.init(frame: frame)
        textViewController.delegate = self
        backgroundColor = .white
        editableTextInteraction.textInput = self
        nonEditableTextInteraction.textInput = self
        editableTextInteraction.delegate = self
        nonEditableTextInteraction.delegate = self
        tapGestureRecognizer.delegate = self
        tapGestureRecognizer.addTarget(self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGestureRecognizer)
        installNonEditableInteraction()
        keyboardObserver.delegate = self
        textSearchingHelper.textView = self
        editMenuController.delegate = self
        editMenuController.setupEditMenu(in: self)
        textViewController.highlightNavigationController.delegate = self
        addSubview(textViewController.layoutManager.lineSelectionBackgroundView)
        addSubview(textViewController.layoutManager.linesContainerView)
        addSubview(textViewController.layoutManager.gutterContainerView)
    }

    /// The initializer has not been implemented.
    /// - Parameter coder: Not used.
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Tells the view that its window object changed.
    override open func didMoveToWindow() {
        super.didMoveToWindow()
        textViewController.performFullLayoutIfNeeded()
    }

    /// Lays out subviews.
    override open func layoutSubviews() {
        super.layoutSubviews()
        hasDeletedTextWithPendingLayoutSubviews = false
        textViewController.scrollViewSize = frame.size
        textViewController.layoutIfNeeded()
        // We notify the input delegate about selection changes in layoutSubviews so we have a chance of disabling notifying the input delegate during an editing operation.
        // We will sometimes disable notifying the input delegate when the user enters Korean text.
        // This workaround is inspired by a dialog with Alexander Blach (@lextar), developer of Textastic.
        if notifyInputDelegateAboutSelectionChangeInLayoutSubviews {
            notifyInputDelegateAboutSelectionChangeInLayoutSubviews = false
            inputDelegate?.selectionWillChange(self)
            inputDelegate?.selectionDidChange(self)
        }
        if notifyDelegateAboutSelectionChangeInLayoutSubviews {
            notifyDelegateAboutSelectionChangeInLayoutSubviews = false
            handleTextSelectionChange()
        }
        textViewController.handleContentSizeUpdateIfNeeded()
        textViewController.viewport = CGRect(origin: contentOffset, size: frame.size)
        textViewController.layoutManager.bringGutterToFront()
        // Setting the frame of the text selection view fixes a bug where UIKit assigns an incorrect
        // Y-position to the selection rects the first time the user selects text.
        // After the initial selection the rectangles would be placed correctly.
        textSelectionView?.frame = .zero
    }

    /// Called when the safe area of the view changes.
    override open func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        textViewController.safeAreaInsets = safeAreaInsets
        layoutIfNeeded()
    }

    /// Asks UIKit to make this object the first responder in its window.
    @discardableResult
    override open func becomeFirstResponder() -> Bool {
        guard !isEditing && shouldBeginEditing else {
            return false
        }
        if canBecomeFirstResponder {
            willBeginEditing()
        }
        let didBecomeFirstResponder = super.becomeFirstResponder()
        if didBecomeFirstResponder {
            didBeginEditing()
        } else {
            didCancelBeginEditing()
        }
        return didBecomeFirstResponder
    }

    /// Notifies this object that it has been asked to relinquish its status as first responder in its window.
    @discardableResult
    override open func resignFirstResponder() -> Bool {
        guard isEditing && shouldEndEditing else {
            return false
        }
        let didResignFirstResponder = super.resignFirstResponder()
        if didResignFirstResponder {
            didEndEditing()
        }
        return didResignFirstResponder
    }

    /// Copy the selected text.
    ///
    /// - Parameter sender: The object calling this method.
    override open func copy(_ sender: Any?) {
        if let selectedTextRange = selectedTextRange, let text = text(in: selectedTextRange) {
            UIPasteboard.general.string = text
        }
    }

    /// Paste text from the pasteboard.
    ///
    /// - Parameter sender: The object calling this method.
    override open func paste(_ sender: Any?) {
        if let selectedTextRange = selectedTextRange, let string = UIPasteboard.general.string {
            inputDelegate?.selectionWillChange(self)
            let preparedText = textViewController.prepareTextForInsertion(string)
            replace(selectedTextRange, withText: preparedText)
            inputDelegate?.selectionDidChange(self)
        }
    }

    /// Cut text  to the pasteboard.
    ///
    /// - Parameter sender: The object calling this method.
    override open func cut(_ sender: Any?) {
        if let selectedTextRange = selectedTextRange, let text = text(in: selectedTextRange) {
            UIPasteboard.general.string = text
            replace(selectedTextRange, withText: "")
        }
    }

    /// Select all text in the text view.
    ///
    /// - Parameter sender: The object calling this method.
    override open func selectAll(_ sender: Any?) {
        notifyInputDelegateAboutSelectionChangeInLayoutSubviews = true
        selectedRange = NSRange(location: 0, length: textViewController.stringView.string.length)
    }

    /// Replace the selected range with the specified text.
    ///
    /// - Parameter obj: Text to replace the selected range with.
    @objc func replace(_ obj: NSObject) {
        /// When autocorrection is enabled and the user tap on a misspelled word, UITextInteraction will present
        /// a UIMenuController with suggestions for the correct spelling of the word. Selecting a suggestion will
        /// cause UITextInteraction to call the non-existing -replace(_:) function and pass an instance of the private
        /// UITextReplacement type as parameter. We can't make autocorrection work properly without using private API.
        if let replacementText = obj.value(forKey: "_repl" + "Ttnemeca".reversed() + "ext") as? String {
            if let indexedRange = obj.value(forKey: "_r" + "gna".reversed() + "e") as? IndexedRange {
                replace(indexedRange, withText: replacementText)
            }
        }
    }

    /// Requests the receiving responder to enable or disable the specified command in the user interface.
    /// - Parameters:
    ///   - action: A selector that identifies a method associated with a command.
    ///   - sender: The object calling this method.
    /// - Returns: true if the command identified by action should be enabled or false if it should be disabled.
    override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(copy(_:)) {
            if let selectedTextRange = selectedTextRange {
                return !selectedTextRange.isEmpty
            } else {
                return false
            }
        } else if action == #selector(cut(_:)) {
            if let selectedTextRange = selectedTextRange {
                return isEditing && !selectedTextRange.isEmpty
            } else {
                return false
            }
        } else if action == #selector(paste(_:)) {
            return isEditing && UIPasteboard.general.hasStrings
        } else if action == #selector(selectAll(_:)) {
            return true
        } else if action == #selector(replace(_:)) {
            return true
        } else if action == NSSelectorFromString("replaceTextInSelectedHighlightedRange") {
            if let selectedRange = textViewController.selectedRange, let highlightedRange = textViewController.highlightedRange(for: selectedRange) {
                return editorDelegate?.textView(self, canReplaceTextIn: highlightedRange) ?? false
            } else {
                return false
            }
        } else {
            return super.canPerformAction(action, withSender: sender)
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
        textViewController.setState(state, addUndoAction: addUndoAction)
    }

    /// Returns the row and column at the specified location in the text.
    /// Common usages of this includes showing the line and column that the caret is currently located at.
    /// - Parameter location: The location is relative to the first index in the string.
    /// - Returns: The text location if the input location could be found in the string, otherwise nil.
    public func textLocation(at location: Int) -> TextLocation? {
        if let linePosition = textViewController.lineManager.linePosition(at: location) {
            return TextLocation(linePosition)
        } else {
            return nil
        }
    }

    /// Returns the character location at the specified row and column.
    /// - Parameter textLocation: The row and column in the text.
    /// - Returns: The location if the input row and column could be found in the text, otherwise nil.
    public func location(at textLocation: TextLocation) -> Int? {
        let lineIndex = textLocation.lineNumber
        guard lineIndex >= 0 && lineIndex < textViewController.lineManager.lineCount else {
            return nil
        }
        let line = textViewController.lineManager.line(atRow: lineIndex)
        guard textLocation.column >= 0 && textLocation.column <= line.data.totalLength else {
            return nil
        }
        return line.location + textLocation.column
    }

    /// Sets the language mode on a background thread.
    ///
    /// - Parameters:
    ///   - languageMode: The new language mode to be used by the editor.
    ///   - completion: Called when the content have been parsed or when parsing fails.
    public func setLanguageMode(_ languageMode: LanguageMode, completion: ((Bool) -> Void)? = nil) {
        textViewController.setLanguageMode(languageMode, completion: completion)
    }

    /// Replaces the text in the specified matches.
    /// - Parameters:
    ///   - batchReplaceSet: Set of ranges to replace with a text.
    public func replaceText(in batchReplaceSet: BatchReplaceSet) {
        textViewController.replaceText(in: batchReplaceSet)
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
        textViewController.syntaxNode(at: location)
    }

    /// Checks if the specified locations is within the indentation of the line.
    ///
    /// - Parameter location: A location in the document.
    /// - Returns: True if the location is within the indentation of the line, otherwise false.
    public func isIndentation(at location: Int) -> Bool {
        textViewController.isIndentation(at: location)
    }

    /// Decreases the indentation level of the selected lines.
    public func shiftLeft() {
        if let selectedRange = textViewController.selectedRange {
            inputDelegate?.textWillChange(self)
            textViewController.indentController.shiftLeft(in: selectedRange)
            inputDelegate?.textDidChange(self)
        }
    }

    /// Increases the indentation level of the selected lines.
    public func shiftRight() {
        if let selectedRange = textViewController.selectedRange {
            inputDelegate?.textWillChange(self)
            textViewController.indentController.shiftRight(in: selectedRange)
            inputDelegate?.textDidChange(self)
        }
    }

    /// Moves the selected lines up by one line.
    ///
    /// Calling this function has no effect when the selected lines include the first line in the text view.
    public func moveSelectedLinesUp() {
        textViewController.moveSelectedLinesUp()
    }

    /// Moves the selected lines down by one line.
    ///
    /// Calling this function has no effect when the selected lines include the last line in the text view.
    public func moveSelectedLinesDown() {
        textViewController.moveSelectedLinesDown()
    }

    /// Attempts to detect the indent strategy used in the document. This may return an unknown strategy even
    /// when the document contains indentation.
    public func detectIndentStrategy() -> DetectedIndentStrategy {
        textViewController.languageMode.detectIndentStrategy()
    }

    /// Go to the beginning of the line at the specified index.
    ///
    /// - Parameter lineIndex: Index of line to navigate to.
    /// - Parameter selection: The placement of the caret on the line.
    /// - Returns: True if the text view could navigate to the specified line index, otherwise false.
    @discardableResult
    public func goToLine(_ lineIndex: Int, select selection: GoToLineSelection = .beginning) -> Bool {
        notifyInputDelegateAboutSelectionChangeInLayoutSubviews = true
        return textViewController.goToLine(lineIndex, select: selection)
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
        let searchController = SearchController(stringView: textViewController.stringView)
        searchController.delegate = self
        return searchController.search(for: query)
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
        let searchController = SearchController(stringView: textViewController.stringView)
        searchController.delegate = self
        return searchController.search(for: query, replacingMatchesWith: replacementString)
    }

    /// Returns a peek into the text view's underlying attributed string.
    /// - Parameter range: Range of text to include in text view. The returned result may span a larger range than the one specified.
    /// - Returns: Text preview containing the specified range.
    public func textPreview(containing range: NSRange) -> TextPreview? {
        textViewController.layoutManager.textPreview(containing: range)
    }

    /// Selects a highlighted range behind the selected range if possible.
    public func selectPreviousHighlightedRange() {
        inputDelegate?.selectionWillChange(self)
        textViewController.highlightNavigationController.selectPreviousRange()
        inputDelegate?.selectionDidChange(self)
    }

    /// Selects a highlighted range after the selected range if possible.
    public func selectNextHighlightedRange() {
        inputDelegate?.selectionWillChange(self)
        textViewController.highlightNavigationController.selectNextRange()
        inputDelegate?.selectionDidChange(self)
    }

    /// Selects the highlighed range at the specified index.
    /// - Parameter index: Index of highlighted range to select.
    public func selectHighlightedRange(at index: Int) {
        inputDelegate?.selectionWillChange(self)
        textViewController.highlightNavigationController.selectRange(at: index)
        inputDelegate?.selectionDidChange(self)
    }

    /// Synchronously displays the visible lines. This can be used to immediately update the visible lines after setting the theme. Use with caution as redisplaying the visible lines can be a costly operation.
    public func redisplayVisibleLines() {
        textViewController.layoutManager.redisplayVisibleLines()
    }

    /// Scrolls the text view to reveal the text in the specified range.
    ///
    /// The function will scroll the text view as little as possible while revealing as much as possible of the specified range. It is not guaranteed that the entire range is visible after performing the scroll.
    ///
    /// - Parameters:
    ///   - range: The range of text to scroll into view.
    public func scrollRangeToVisible(_ range: NSRange) {
        textViewController.scrollRangeToVisible(range)
    }

    /// Replaces the text that is in the specified range.
     /// - Parameters:
     ///   - range: A range of text in the document.
     ///   - text: A string to replace the text in range.
    public func replace(_ range: NSRange, withText text: String) {
        inputDelegate?.selectionWillChange(self)
        let indexedRange = IndexedRange(range)
        replace(indexedRange, withText: text)
        inputDelegate?.selectionDidChange(self)
    }

    /// Returns the text in the specified range.
    /// - Parameter range: A range of text in the document.
    /// - Returns: The substring that falls within the specified range.
    public func text(in range: NSRange) -> String? {
        textViewController.text(in: range)
    }

    /// Called when the iOS interface environment changes.
    override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            textViewController.invalidateLines()
            textViewController.layoutManager.setNeedsLayout()
        }
    }

    /// Returns the farthest descendant of the receiver in the view hierarchy (including itself) that contains a specified point.
    /// - Parameters:
    ///   - point: A point specified in the receiver's local coordinate system (bounds).
    ///   - event: The event that warranted a call to this method. If you are calling this method from outside your event-handling code, you may specify nil.
    /// - Returns: The view object that is the farthest descendent of the current view and contains point. Returns nil if the point lies completely outside the receiver's view hierarchy.
    override open func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard isSelectable else {
            return nil
        }
        // We end our current undo group when the user touches the view.
        let result = super.hitTest(point, with: event)
        if result === self {
            undoManager?.endUndoGrouping()
        }
        return result
    }

    /// Tells the object when a button is released.
    /// - Parameters:
    ///   - presses: A set of UIPress instances that represent the buttons that the user is no longer pressing.
    ///   - event: The event to which the presses belong.
    override open func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
        if let keyCode = presses.first?.key?.keyCode, presses.count == 1, textViewController.markedRange != nil {
            handleKeyPressDuringMultistageTextInput(keyCode: keyCode)
        }
    }
}

extension TextView {
    var viewHierarchyContainsCaret: Bool {
        textSelectionView?.subviews.count == 1
    }
    var textSelectionView: UIView? {
        if let klass = NSClassFromString("UITextSelectionView") {
            return subviews.first { $0.isKind(of: klass) }
        } else {
            return nil
        }
    }

    private func handleTextSelectionChange() {
        UIMenuController.shared.hideMenu(from: self)
        scrollToVisibleLocationIfNeeded()
        editorDelegate?.textViewDidChangeSelection(self)
    }

    func sendSelectionChangedToTextSelectionView() {
        // The only way I've found to get the selection change to be reflected properly while still supporting Korean, Chinese, and deleting words with Option+Backspace is to call a private API in some cases. However, as pointed out by Alexander Blach in the following PR, there is another workaround to the issue.
        // When passing nil to the input delete, the text selection is update but the text input ignores it.
        // Even the Swift Playgrounds app does not get this right for all languages in all cases, so there seems to be some workarounds needed to due bugs in internal classes in UIKit that communicate with instances of UITextInput.
        inputDelegate?.selectionDidChange(nil)
    }

    func removeAndAddEditableTextInteraction() {
        // There seems to be a bug in UITextInput (or UITextInteraction?) where updating the markedTextRange of a UITextInput will cause the caret to disappear. Removing the editable text interaction and adding it back will work around this issue.
        DispatchQueue.main.async {
            if !self.viewHierarchyContainsCaret && self.editableTextInteraction.view != nil {
                self.removeInteraction(self.editableTextInteraction)
                self.addInteraction(self.editableTextInteraction)
            }
        }
    }

    func updateCaretColor() {
        // Removing the UITextSelectionView and re-adding it forces it to query the insertion point color.
        if let textSelectionView = textSelectionView {
            textSelectionView.removeFromSuperview()
            addSubview(textSelectionView)
        }
    }
}

private extension TextView {
    private func willBeginEditing() {
        guard isEditable else {
            return
        }
        textViewController.isEditing = !isPerformingNonEditableTextInteraction
        // If a developer is programmatically calling becomeFirstResponder() then we might not have a selected range.
        // We set the selectedRange instead of the selectedTextRange to avoid invoking any delegates.
        if textViewController.selectedRange == nil && !isPerformingNonEditableTextInteraction {
            textViewController.selectedRange = NSRange(location: 0, length: 0)
        }
        // Ensure selection is laid out without animation.
        UIView.performWithoutAnimation {
            layoutIfNeeded()
        }
        // The editable interaction must be installed early in the -becomeFirstResponder() call
        if !isPerformingNonEditableTextInteraction {
            installEditableInteraction()
        }
    }

    private func didBeginEditing() {
        if !isPerformingNonEditableTextInteraction {
            editorDelegate?.textViewDidBeginEditing(self)
        }
    }

    private func didCancelBeginEditing() {
        // This is called in the case where:
        // 1. The view is the first responder.
        // 2. A view is presented modally on top of the editor.
        // 3. The modally presented view is dismissed.
        // 4. The responder chain attempts to make the text view first responder again but super.becomeFirstResponder() returns false.
        textViewController.isEditing = false
        installNonEditableInteraction()
    }

    private func didEndEditing() {
        textViewController.isEditing = false
        installNonEditableInteraction()
        editorDelegate?.textViewDidEndEditing(self)
    }

    private func installEditableInteraction() {
        if editableTextInteraction.view == nil {
            isInputAccessoryViewEnabled = true
            removeInteraction(nonEditableTextInteraction)
            addInteraction(editableTextInteraction)
        }
    }

    private func installNonEditableInteraction() {
        if nonEditableTextInteraction.view == nil {
            isInputAccessoryViewEnabled = false
            removeInteraction(editableTextInteraction)
            addInteraction(nonEditableTextInteraction)
            for gestureRecognizer in nonEditableTextInteraction.gesturesForFailureRequirements {
                gestureRecognizer.require(toFail: tapGestureRecognizer)
            }
        }
    }

    @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard isSelectable, gestureRecognizer.state == .ended else {
            return
        }
        let point = gestureRecognizer.location(in: self)
        let oldSelectedRange = selectedRange
        let index = textViewController.layoutManager.closestIndex(to: point)
        selectedRange = NSRange(location: index, length: 0)
        if selectedRange != oldSelectedRange {
            layoutIfNeeded()
        }
        installEditableInteraction()
        becomeFirstResponder()
    }

    @objc private func handleTextRangeAdjustmentPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        // This function scroll the text view when the selected range is adjusted.
        if gestureRecognizer.state == .began {
            previousSelectedRangeDuringGestureHandling = selectedRange
        } else if gestureRecognizer.state == .changed, let previousSelectedRange = previousSelectedRangeDuringGestureHandling {
            if selectedRange.lowerBound != previousSelectedRange.lowerBound {
                // User is adjusting the lower bound (location) of the selected range.
                textViewController.scrollLocationToVisible(selectedRange.lowerBound)
            } else if selectedRange.upperBound != previousSelectedRange.upperBound {
                // User is adjusting the upper bound (length) of the selected range.
                textViewController.scrollLocationToVisible(selectedRange.upperBound)
            }
            previousSelectedRangeDuringGestureHandling = selectedRange
        }
    }

    @objc private func replaceTextInSelectedHighlightedRange() {
        if let selectedRange = textViewController.selectedRange, let highlightedRange = textViewController.highlightedRange(for: selectedRange) {
            editorDelegate?.textView(self, replaceTextIn: highlightedRange)
        }
    }

    private func handleKeyPressDuringMultistageTextInput(keyCode: UIKeyboardHIDUsage) {
        // When editing multistage text input (that is, we have a marked text) we let the user unmark the text
        // by pressing the arrow keys or Escape. This isn't common in iOS apps but it's the default behavior
        // on macOS and I think that works quite well for plain text editors on iOS too.
        guard let markedRange = textViewController.markedRange, let markedText = textViewController.stringView.substring(in: markedRange) else {
            return
        }
        // We only unmark the text if the marked text contains specific characters only.
        // Some languages use multistage text input extensively and for those iOS presents a UI when
        // navigating with the arrow keys. We do not want to interfere with that interaction.
        let characterSet = CharacterSet(charactersIn: "`´^¨")
        guard markedText.rangeOfCharacter(from: characterSet.inverted) == nil else {
            return
        }
        switch keyCode {
        case .keyboardUpArrow:
            textViewController.moveUp()
            unmarkText()
        case .keyboardRightArrow:
            textViewController.moveRight()
            unmarkText()
        case .keyboardDownArrow:
            textViewController.moveDown()
            unmarkText()
        case .keyboardLeftArrow:
            textViewController.moveLeft()
            unmarkText()
        case .keyboardEscape:
            unmarkText()
        default:
            break
        }
    }

    private func scrollToVisibleLocationIfNeeded() {
        if isAutomaticScrollEnabled, let newRange = textViewController.selectedRange, newRange.length == 0 {
            textViewController.scrollLocationToVisible(newRange.location)
        }
    }
}

// MARK: - TextViewControllerDelegate
extension TextView: TextViewControllerDelegate {
    func textViewControllerDidChangeText(_ textViewController: TextViewController) {
        editorDelegate?.textViewDidChange(self)
    }

    func textViewController(_ textViewController: TextViewController, didChangeSelectedRange selectedRange: NSRange?) {
        UIMenuController.shared.hideMenu(from: self)
        scrollToVisibleLocationIfNeeded()
        editorDelegate?.textViewDidChangeSelection(self)
    }
}

// MARK: - SearchControllerDelegate
extension TextView: SearchControllerDelegate {
    func searchController(_ searchController: SearchController, linePositionAt location: Int) -> LinePosition? {
        textViewController.lineManager.linePosition(at: location)
    }
}

// MARK: - UIGestureRecognizerDelegate
extension TextView: UIGestureRecognizerDelegate {
    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === tapGestureRecognizer {
            return !isEditing && !isDragging && !isDecelerating && shouldBeginEditing
        } else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if let klass = NSClassFromString("UITextRangeAdjustmentGestureRecognizer") {
            if !textRangeAdjustmentGestureRecognizers.contains(otherGestureRecognizer) && otherGestureRecognizer.isKind(of: klass) {
                otherGestureRecognizer.addTarget(self, action: #selector(handleTextRangeAdjustmentPan(_:)))
                textRangeAdjustmentGestureRecognizers.insert(otherGestureRecognizer)
            }
        }
        return gestureRecognizer !== panGestureRecognizer
    }
}

// MARK: - KeyboardObserverDelegate
extension TextView: KeyboardObserverDelegate {
    func keyboardObserver(
        _ keyboardObserver: KeyboardObserver,
        keyboardWillShowWithHeight keyboardHeight: CGFloat,
        animation: KeyboardObserver.Animation?
    ) {
        scrollToVisibleLocationIfNeeded()
    }
}

// MARK: - UITextInteractionDelegate
extension TextView: UITextInteractionDelegate {
    public func interactionShouldBegin(_ interaction: UITextInteraction, at point: CGPoint) -> Bool {
        if interaction.textInteractionMode == .editable {
            return isEditable
        } else if interaction.textInteractionMode == .nonEditable {
            // The private UITextLoupeInteraction and UITextNonEditableInteractionclass will end up in this case. The latter is likely created from UITextInteraction(for: .nonEditable) but we want to disable both when selection is disabled.
            return isSelectable
        } else {
            return true
        }
    }

    public func interactionWillBegin(_ interaction: UITextInteraction) {
        if interaction.textInteractionMode == .nonEditable {
            // When long-pressing our instance of UITextInput, the UITextInteraction will make the text input first responder.
            // In this case the user wants to select text in the text view but not start editing, so we set a flag that tells us
            // that we should not install editable text interaction in this case.
            isPerformingNonEditableTextInteraction = true
        }
    }

    public func interactionDidEnd(_ interaction: UITextInteraction) {
        if interaction.textInteractionMode == .nonEditable {
            isPerformingNonEditableTextInteraction = false
        }
    }
}

// MARK: - EditMenuControllerDelegate
extension TextView: EditMenuControllerDelegate {
    func editMenuController(_ controller: EditMenuController, caretRectAt location: Int) -> CGRect {
        let caretRectFactory = CaretRectFactory(
            stringView: textViewController.stringView,
            lineManager: textViewController.lineManager,
            lineControllerStorage: textViewController.lineControllerStorage,
            gutterWidthService: textViewController.gutterWidthService,
            textContainerInset: textContainerInset
        )
        return caretRectFactory.caretRect(at: location, allowMovingCaretToNextLineFragment: false)
    }

    func editMenuControllerShouldReplaceText(_ controller: EditMenuController) {
        replaceTextInSelectedHighlightedRange()
    }

    func editMenuController(_ controller: EditMenuController, canReplaceTextIn highlightedRange: HighlightedRange) -> Bool {
        editorDelegate?.textView(self, canReplaceTextIn: highlightedRange) ?? false
    }

    func editMenuController(_ controller: EditMenuController, highlightedRangeFor range: NSRange) -> HighlightedRange? {
        highlightedRanges.first { $0.range == range }
    }

    func selectedRange(for controller: EditMenuController) -> NSRange? {
        selectedRange
    }
}

// MARK: - HighlightNavigationControllerDelegate
extension TextView: HighlightNavigationControllerDelegate {
    func highlightNavigationController(
        _ controller: HighlightNavigationController,
        shouldNavigateTo highlightNavigationRange: HighlightNavigationRange
    ) {
        let range = highlightNavigationRange.range
        scrollRangeToVisible(range)
        selectedTextRange = IndexedRange(range)
        _ = becomeFirstResponder()
        if showMenuAfterNavigatingToHighlightedRange {
            editMenuController.presentEditMenu(from: self, forTextIn: range)
        }
        switch highlightNavigationRange.loopMode {
        case .previousGoesToLast:
            editorDelegate?.textViewDidLoopToLastHighlightedRange(self)
        case .nextGoesToFirst:
            editorDelegate?.textViewDidLoopToFirstHighlightedRange(self)
        case .disabled:
            break
        }
    }
}
#endif
