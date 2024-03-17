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
    /// Delegate to receive callbacks for events triggered by the editor.
    public weak var editorDelegate: TextViewDelegate?
    /// Whether the text view is in a state where the contents can be edited.
    public private(set) var isEditing = false {
        didSet {
            if isEditing != oldValue {
                textInputView.isEditing = isEditing
            }
        }
    }
    /// The text that the text view displays.
    public var text: String {
        get {
            textInputView.string as String
        }
        set {
            textInputView.string = newValue as NSString
            contentSize = preferredContentSize
        }
    }
    /// A Boolean value that indicates whether the text view is editable.
    public var isEditable = true {
        didSet {
            if isEditable != oldValue && !isEditable && isEditing {
                resignFirstResponder()
                textInputViewDidEndEditing(textInputView)
            }
        }
    }
    /// A Boolean value that indicates whether the text view is selectable.
    public var isSelectable = true {
        didSet {
            if isSelectable != oldValue {
                textInputView.isUserInteractionEnabled = isSelectable
                if !isSelectable && isEditing {
                    resignFirstResponder()
                    textInputView.clearSelection()
                    textInputViewDidEndEditing(textInputView)
                }
            }
        }
    }
    /// Colors and fonts to be used by the editor.
    public var theme: Theme {
        get {
            textInputView.theme
        }
        set {
            textInputView.theme = newValue
        }
    }
    /// The autocorrection style for the text view.
    public var autocorrectionType: UITextAutocorrectionType {
        get {
            textInputView.autocorrectionType
        }
        set {
            textInputView.autocorrectionType = newValue
        }
    }
    /// The autocapitalization style for the text view.
    public var autocapitalizationType: UITextAutocapitalizationType {
        get {
            textInputView.autocapitalizationType
        }
        set {
            textInputView.autocapitalizationType = newValue
        }
    }
    /// The spell-checking style for the text view.
    public var smartQuotesType: UITextSmartQuotesType {
        get {
            textInputView.smartQuotesType
        }
        set {
            textInputView.smartQuotesType = newValue
        }
    }
    /// The configuration state for smart dashes.
    public var smartDashesType: UITextSmartDashesType {
        get {
            textInputView.smartDashesType
        }
        set {
            textInputView.smartDashesType = newValue
        }
    }
    /// The configuration state for the smart insertion and deletion of space characters.
    public var smartInsertDeleteType: UITextSmartInsertDeleteType {
        get {
            textInputView.smartInsertDeleteType
        }
        set {
            textInputView.smartInsertDeleteType = newValue
        }
    }
    /// The spell-checking style for the text object.
    public var spellCheckingType: UITextSpellCheckingType {
        get {
            textInputView.spellCheckingType
        }
        set {
            textInputView.spellCheckingType = newValue
        }
    }
    /// The keyboard type for the text view.
    public var keyboardType: UIKeyboardType {
        get {
            textInputView.keyboardType
        }
        set {
            textInputView.keyboardType = newValue
        }
    }
    /// The appearance style of the keyboard for the text view.
    public var keyboardAppearance: UIKeyboardAppearance {
        get {
            textInputView.keyboardAppearance
        }
        set {
            textInputView.keyboardAppearance = newValue
        }
    }
    /// The display of the return key.
    public var returnKeyType: UIReturnKeyType {
        get {
            textInputView.returnKeyType
        }
        set {
            textInputView.returnKeyType = newValue
        }
    }
    /// Returns the undo manager used by the text view.
    override public var undoManager: UndoManager? {
        textInputView.undoManager
    }
    /// The color of the insertion point. This can be used to control the color of the caret.
    public var insertionPointColor: UIColor {
        get {
            textInputView.insertionPointColor
        }
        set {
            textInputView.insertionPointColor = newValue
        }
    }
    /// The color of the selection bar. It is most common to set this to the same color as the color used for the insertion point.
    public var selectionBarColor: UIColor {
        get {
            textInputView.selectionBarColor
        }
        set {
            textInputView.selectionBarColor = newValue
        }
    }
    /// The color of the selection highlight. It is most common to set this to the same color as the color used for the insertion point.
    public var selectionHighlightColor: UIColor {
        get {
            textInputView.selectionHighlightColor
        }
        set {
            textInputView.selectionHighlightColor = newValue
        }
    }
    /// The current selection range of the text view.
    public var selectedRange: NSRange {
        get {
            if let selectedRange = textInputView.selectedRange {
                return selectedRange
            } else {
                // UITextView returns the end of the document for the selectedRange by default.
                return NSRange(location: textInputView.string.length, length: 0)
            }
        }
        set {
            textInputView.selectedTextRange = IndexedRange(newValue)
        }
    }
    /// The current selection range of the text view as a UITextRange.
    public var selectedTextRange: UITextRange? {
        get {
            textInputView.selectedTextRange
        }
        set {
            textInputView.selectedTextRange = newValue
        }
    }
    #if compiler(<5.9) || !os(visionOS)
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
    #endif
    #if compiler(<5.9) || !os(visionOS)
    /// The input assistant to use when configuring the keyboard's shortcuts bar.
    override public var inputAssistantItem: UITextInputAssistantItem {
        textInputView.inputAssistantItem
    }
    #endif
    /// Returns a Boolean value indicating whether this object can become the first responder.
    override public var canBecomeFirstResponder: Bool {
        !textInputView.isFirstResponder && isEditable
    }
    /// The text view's background color.
    override public var backgroundColor: UIColor? {
        get {
            textInputView.backgroundColor
        }
        set {
            super.backgroundColor = newValue
            textInputView.backgroundColor = newValue
        }
    }
    /// The point at which the origin of the content view is offset from the origin of the scroll view.
    override public var contentOffset: CGPoint {
        didSet {
            if contentOffset != oldValue {
                textInputView.viewport = CGRect(origin: contentOffset, size: frame.size)
            }
        }
    }
    /// Character pairs are used by the editor to automatically insert a trailing character when the user types the leading character.
    ///
    /// Common usages of this includes the \" character to surround strings and { } to surround a scope.
    public var characterPairs: [CharacterPair] {
        get {
            textInputView.characterPairs
        }
        set {
            textInputView.characterPairs = newValue
        }
    }
    /// Determines what should happen to the trailing component of a character pair when deleting the leading component. Defaults to `disabled` meaning that nothing will happen.
    public var characterPairTrailingComponentDeletionMode: CharacterPairTrailingComponentDeletionMode {
        get {
            textInputView.characterPairTrailingComponentDeletionMode
        }
        set {
            textInputView.characterPairTrailingComponentDeletionMode = newValue
        }
    }
    /// Enable to show line numbers in the gutter.
    public var showLineNumbers: Bool {
        get {
            textInputView.showLineNumbers
        }
        set {
            textInputView.showLineNumbers = newValue
        }
    }
    /// Enable to show highlight the selected lines. The selection is only shown in the gutter when multiple lines are selected.
    public var lineSelectionDisplayType: LineSelectionDisplayType {
        get {
            textInputView.lineSelectionDisplayType
        }
        set {
            textInputView.lineSelectionDisplayType = newValue
        }
    }
    /// The text view renders invisible tabs when enabled. The `tabsSymbol` is used to render tabs.
    public var showTabs: Bool {
        get {
            textInputView.showTabs
        }
        set {
            textInputView.showTabs = newValue
        }
    }
    /// The text view renders invisible spaces when enabled.
    ///
    /// he `spaceSymbol` is used to render spaces.
    public var showSpaces: Bool {
        get {
            textInputView.showSpaces
        }
        set {
            textInputView.showSpaces = newValue
        }
    }
    /// The text view renders invisible spaces when enabled.
    ///
    /// The `nonBreakingSpaceSymbol` is used to render spaces.
    public var showNonBreakingSpaces: Bool {
        get {
            textInputView.showNonBreakingSpaces
        }
        set {
            textInputView.showNonBreakingSpaces = newValue
        }
    }
    /// The text view renders invisible line breaks when enabled.
    ///
    /// The `lineBreakSymbol` is used to render line breaks.
    public var showLineBreaks: Bool {
        get {
            textInputView.showLineBreaks
        }
        set {
            textInputView.showLineBreaks = newValue
        }
    }
    /// The text view renders invisible soft line breaks when enabled.
    ///
    /// The `softLineBreakSymbol` is used to render line breaks. These line breaks are typically represented by the U+2028 unicode character. Runestone does not provide any key commands for inserting these but supports rendering them.
    public var showSoftLineBreaks: Bool {
        get {
            textInputView.showSoftLineBreaks
        }
        set {
            textInputView.showSoftLineBreaks = newValue
        }
    }
    /// Symbol used to display tabs.
    ///
    /// The value is only used when invisible tab characters is enabled. The default is ▸.
    ///
    /// Common characters for this symbol include ▸, ⇥, ➜, ➞, and ❯.
    public var tabSymbol: String {
        get {
            textInputView.tabSymbol
        }
        set {
            textInputView.tabSymbol = newValue
        }
    }
    /// Symbol used to display spaces.
    ///
    /// The value is only used when showing invisible space characters is enabled. The default is ·.
    ///
    /// Common characters for this symbol include ·, •, and _.
    public var spaceSymbol: String {
        get {
            textInputView.spaceSymbol
        }
        set {
            textInputView.spaceSymbol = newValue
        }
    }
    /// Symbol used to display non-breaking spaces.
    ///
    /// The value is only used when showing invisible space characters is enabled. The default is ·.
    ///
    /// Common characters for this symbol include ·, •, and _.
    public var nonBreakingSpaceSymbol: String {
        get {
            textInputView.nonBreakingSpaceSymbol
        }
        set {
            textInputView.nonBreakingSpaceSymbol = newValue
        }
    }
    /// Symbol used to display line break.
    ///
    /// The value is only used when showing invisible line break characters is enabled. The default is ¬.
    ///
    /// Common characters for this symbol include ¬, ↵, ↲, ⤶, and ¶.
    public var lineBreakSymbol: String {
        get {
            textInputView.lineBreakSymbol
        }
        set {
            textInputView.lineBreakSymbol = newValue
        }
    }
    /// Symbol used to display soft line breaks.
    ///
    /// The value is only used when showing invisible soft line break characters is enabled. The default is ¬.
    ///
    /// Common characters for this symbol include ¬, ↵, ↲, ⤶, and ¶.
    public var softLineBreakSymbol: String {
        get {
            textInputView.softLineBreakSymbol
        }
        set {
            textInputView.softLineBreakSymbol = newValue
        }
    }
    /// The strategy used when indenting text.
    public var indentStrategy: IndentStrategy {
        get {
            textInputView.indentStrategy
        }
        set {
            textInputView.indentStrategy = newValue
        }
    }
    /// The amount of padding before the line numbers inside the gutter.
    public var gutterLeadingPadding: CGFloat {
        get {
            textInputView.gutterLeadingPadding
        }
        set {
            textInputView.gutterLeadingPadding = newValue
        }
    }
    /// The amount of padding after the line numbers inside the gutter.
    public var gutterTrailingPadding: CGFloat {
        get {
            textInputView.gutterTrailingPadding
        }
        set {
            textInputView.gutterTrailingPadding = newValue
        }
    }
    /// The minimum amount of characters to use for width calculation inside the gutter.
    public var gutterMinimumCharacterCount: Int {
        get {
            textInputView.gutterMinimumCharacterCount
        }
        set {
            textInputView.gutterMinimumCharacterCount = newValue
        }
    }
    /// The amount of spacing surrounding the lines.
    public var textContainerInset: UIEdgeInsets {
        get {
            textInputView.textContainerInset
        }
        set {
            textInputView.textContainerInset = newValue
        }
    }
    /// When line wrapping is disabled, users can scroll the text view horizontally to see the entire line.
    ///
    /// Line wrapping is enabled by default.
    public var isLineWrappingEnabled: Bool {
        get {
            textInputView.isLineWrappingEnabled
        }
        set {
            textInputView.isLineWrappingEnabled = newValue
        }
    }
    /// Line break mode for text view. The default value is .byWordWrapping meaning that wrapping occurs on word boundaries.
    public var lineBreakMode: LineBreakMode {
        get {
            textInputView.lineBreakMode
        }
        set {
            textInputView.lineBreakMode = newValue
        }
    }
    /// Width of the gutter.
    public var gutterWidth: CGFloat {
        textInputView.gutterWidth
    }
    /// The line-height is multiplied with the value.
    public var lineHeightMultiplier: CGFloat {
        get {
            textInputView.lineHeightMultiplier
        }
        set {
            textInputView.lineHeightMultiplier = newValue
        }
    }
    /// The number of points by which to adjust kern. The default value is 0 meaning that kerning is disabled.
    public var kern: CGFloat {
        get {
            textInputView.kern
        }
        set {
            textInputView.kern = newValue
        }
    }
    /// The text view shows a page guide when enabled. Use `pageGuideColumn` to specify the location of the page guide.
    public var showPageGuide: Bool {
        get {
            textInputView.showPageGuide
        }
        set {
            textInputView.showPageGuide = newValue
        }
    }
    /// Specifies the location of the page guide. Use `showPageGuide` to specify if the page guide should be shown.
    public var pageGuideColumn: Int {
        get {
            textInputView.pageGuideColumn
        }
        set {
            textInputView.pageGuideColumn = newValue
        }
    }
    /// Automatically scrolls the text view to show the caret when typing or moving the caret.
    public var isAutomaticScrollEnabled = true
    /// Amount of overscroll to add in the vertical direction.
    ///
    /// The overscroll is a factor of the scrollable area height and will not take into account any insets. 0 means no overscroll and 1 means an amount equal to the height of the text view. Detaults to 0.
    public var verticalOverscrollFactor: CGFloat = 0 {
        didSet {
            if horizontalOverscrollFactor != oldValue {
                hasPendingContentSizeUpdate = true
                handleContentSizeUpdateIfNeeded()
            }
        }
    }
    /// Amount of overscroll to add in the horizontal direction.
    ///
    /// The overscroll is a factor of the scrollable area height and will not take into account any insets or the width of the gutter. 0 means no overscroll and 1 means an amount equal to the width of the text view. Detaults to 0.
    public var horizontalOverscrollFactor: CGFloat = 0 {
        didSet {
            if horizontalOverscrollFactor != oldValue {
                hasPendingContentSizeUpdate = true
                handleContentSizeUpdateIfNeeded()
            }
        }
    }
    /// Ranges in the text to be highlighted. The color defined by the background will be drawen behind the text.
    public var highlightedRanges: [HighlightedRange] {
        get {
            textInputView.highlightedRanges
        }
        set {
            textInputView.highlightedRanges = newValue
            highlightNavigationController.highlightedRanges = newValue
        }
    }
    /// Wheter the text view should loop when navigating through highlighted ranges using `selectPreviousHighlightedRange` or `selectNextHighlightedRange` on the text view.
    public var highlightedRangeLoopingMode: HighlightedRangeLoopingMode {
        get {
            if highlightNavigationController.loopRanges {
                return .enabled
            } else {
                return .disabled
            }
        }
        set {
            switch newValue {
            case .enabled:
                highlightNavigationController.loopRanges = true
            case .disabled:
                highlightNavigationController.loopRanges = false
            }
        }
    }
    /// Line endings to use when inserting a line break.
    ///
    /// The value only affects new line breaks inserted in the text view and changing this value does not change the line endings of the text in the text view. Defaults to Unix (LF).
    ///
    /// The TextView will only update the line endings when text is modified through an external event, such as when the user typing on the keyboard, when the user is replacing selected text, and when pasting text into the text view. In all other cases, you should make sure that the text provided to the text view uses the desired line endings. This includes when calling ``TextView/setState(_:addUndoAction:)`` and ``TextView/replaceText(in:)``.
    public var lineEndings: LineEnding {
        get {
            textInputView.lineEndings
        }
        set {
            textInputView.lineEndings = newValue
        }
    }
    /// When enabled the text view will present a menu with actions actions such as Copy and Replace after navigating to a highlighted range.
    public var showMenuAfterNavigatingToHighlightedRange = true
    /// A boolean value that enables a text view’s built-in find interaction.
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
    /// The text view’s built-in find interaction.
    ///
    /// Set <doc:isFindInteractionEnabled> to true to enable the text view's built-in find interaction. This method returns nil when the interaction isn't enabled.
    ///
    /// Call [`presentFindNavigator(showingReplace:)`](https://developer.apple.com/documentation/uikit/uifindinteraction/3975832-presentfindnavigator) on the UIFindInteraction object to invoke the find interaction and display the find panel.
    @available(iOS 16, *)
    public var findInteraction: UIFindInteraction? {
        textSearchingHelper.findInteraction
    }

    private let textInputView: TextInputView
    private let editableTextInteraction = UITextInteraction(for: .editable)
    private let nonEditableTextInteraction = UITextInteraction(for: .nonEditable)
    @available(iOS 16.0, *)
    private var editMenuInteraction: UIEditMenuInteraction? {
        _editMenuInteraction as? UIEditMenuInteraction
    }
    private var _editMenuInteraction: Any?
    private let tapGestureRecognizer = QuickTapGestureRecognizer()
    private var _inputAccessoryView: UIView?
    private var isPerformingNonEditableTextInteraction = false
    private var delegateAllowsEditingToBegin: Bool {
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
    private var hasPendingContentSizeUpdate = false
    private var isInputAccessoryViewEnabled = false
    private let keyboardObserver = KeyboardObserver()
    private let highlightNavigationController = HighlightNavigationController()
    private var textSearchingHelper = UITextSearchingHelper()
    // Store a reference to instances of the private type UITextRangeAdjustmentGestureRecognizer in order to track adjustments
    // to the selected text range and scroll the text view when the handles approach the bottom.
    // The approach is based on the one described in Steve Shephard's blog post "Adventures with UITextInteraction".
    // https://steveshepard.com/blog/adventures-with-uitextinteraction/
    private var textRangeAdjustmentGestureRecognizers: Set<UIGestureRecognizer> = []
    private var previousSelectedRangeDuringGestureHandling: NSRange?
    private var preferredContentSize: CGSize {
        let horizontalOverscrollLength = max(frame.width * horizontalOverscrollFactor, 0)
        let verticalOverscrollLength = max(frame.height * verticalOverscrollFactor, 0)
        let baseContentSize = textInputView.contentSize
        let width = isLineWrappingEnabled ? baseContentSize.width : baseContentSize.width + horizontalOverscrollLength
        let height = baseContentSize.height + verticalOverscrollLength
        return CGSize(width: width, height: height)
    }

    /// Create a new text view.
    /// - Parameter frame: The frame rectangle of the text view.
    override public init(frame: CGRect) {
        textInputView = TextInputView(theme: DefaultTheme())
        super.init(frame: frame)
        backgroundColor = .white
        textInputView.delegate = self
        textInputView.gutterParentView = self
        editableTextInteraction.textInput = textInputView
        nonEditableTextInteraction.textInput = textInputView
        editableTextInteraction.delegate = self
        nonEditableTextInteraction.delegate = self
        addSubview(textInputView)
        tapGestureRecognizer.delegate = self
        tapGestureRecognizer.addTarget(self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGestureRecognizer)
        installNonEditableInteraction()
        keyboardObserver.delegate = self
        highlightNavigationController.delegate = self
        textSearchingHelper.textView = self
    }

    /// The initializer has not been implemented.
    /// - Parameter coder: Not used.
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Lays out subviews.
    override open func layoutSubviews() {
        super.layoutSubviews()
        handleContentSizeUpdateIfNeeded()
        textInputView.scrollViewWidth = frame.width
        textInputView.frame = CGRect(x: 0, y: 0, width: max(contentSize.width, frame.width), height: max(contentSize.height, frame.height))
        textInputView.viewport = CGRect(origin: contentOffset, size: frame.size)
        bringSubviewToFront(textInputView.gutterContainerView)
    }

    /// Called when the safe area of the view changes.
    override open func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        textInputView.scrollViewSafeAreaInsets = safeAreaInsets
        contentSize = preferredContentSize
        layoutIfNeeded()
    }

    /// Asks UIKit to make this object the first responder in its window.
    @discardableResult
    override open func becomeFirstResponder() -> Bool {
        if !isEditing && delegateAllowsEditingToBegin {
            _ = textInputView.resignFirstResponder()
            _ = textInputView.becomeFirstResponder()
            return true
        } else {
            return false
        }
    }

    /// Notifies this object that it has been asked to relinquish its status as first responder in its window.
    @discardableResult
    override open func resignFirstResponder() -> Bool {
        if isEditing && shouldEndEditing {
            return textInputView.resignFirstResponder()
        } else {
            return false
        }
    }

    /// Updates the custom input and accessory views when the object is the first responder.
    override open func reloadInputViews() {
        textInputView.reloadInputViews()
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
        textInputView.setState(state, addUndoAction: addUndoAction)
        contentSize = preferredContentSize
    }

    /// Returns the row and column at the specified location in the text.
    /// Common usages of this includes showing the line and column that the caret is currently located at.
    /// - Parameter location: The location is relative to the first index in the string.
    /// - Returns: The text location if the input location could be found in the string, otherwise nil.
    public func textLocation(at location: Int) -> TextLocation? {
        if let linePosition = textInputView.linePosition(at: location) {
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
        guard lineIndex >= 0 && lineIndex < textInputView.lineManager.lineCount else {
            return nil
        }
        let line = textInputView.lineManager.line(atRow: lineIndex)
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
        textInputView.setLanguageMode(languageMode, completion: completion)
    }

    /// Inserts text at the location of the caret or, if no selection or caret is present, at the end of the text.
    /// - Parameter text: A string to insert.
    open func insertText(_ text: String) {
        textInputView.inputDelegate?.selectionWillChange(textInputView)
        textInputView.insertText(text)
        textInputView.inputDelegate?.selectionDidChange(textInputView)
    }

    /// Replaces the text that is in the specified range.
    /// - Parameters:
    ///   - range: A range of text in the document.
    ///   - text: A string to replace the text in range.
    open func replace(_ range: UITextRange, withText text: String) {
        textInputView.inputDelegate?.selectionWillChange(textInputView)
        textInputView.replace(range, withText: text)
        textInputView.inputDelegate?.selectionDidChange(textInputView)
    }

    /// Replaces the text that is in the specified range.
    /// - Parameters:
    ///   - range: A range of text in the document.
    ///   - text: A string to replace the text in range.
    public func replace(_ range: NSRange, withText text: String) {
        textInputView.inputDelegate?.selectionWillChange(textInputView)
        let indexedRange = IndexedRange(range)
        textInputView.replace(indexedRange, withText: text)
        textInputView.inputDelegate?.selectionDidChange(textInputView)
    }

    /// Replaces the text in the specified matches.
    /// - Parameters:
    ///   - batchReplaceSet: Set of ranges to replace with a text.
    public func replaceText(in batchReplaceSet: BatchReplaceSet) {
        textInputView.replaceText(in: batchReplaceSet)
    }

    /// Deletes a character from the displayed text.
    public func deleteBackward() {
        textInputView.deleteBackward()
    }

    /// Returns the text in the specified range.
    /// - Parameter range: A range of text in the document.
    /// - Returns: The substring that falls within the specified range.
    public func text(in range: NSRange) -> String? {
        textInputView.text(in: range)
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
        textInputView.syntaxNode(at: location)
    }

    /// Checks if the specified locations is within the indentation of the line.
    ///
    /// - Parameter location: A location in the document.
    /// - Returns: True if the location is within the indentation of the line, otherwise false.
    public func isIndentation(at location: Int) -> Bool {
        textInputView.isIndentation(at: location)
    }

    /// Decreases the indentation level of the selected lines.
    public func shiftLeft() {
        textInputView.shiftLeft()
    }

    /// Increases the indentation level of the selected lines.
    public func shiftRight() {
        textInputView.shiftRight()
    }

    /// Moves the selected lines up by one line.
    ///
    /// Calling this function has no effect when the selected lines include the first line in the text view.
    public func moveSelectedLinesUp() {
        textInputView.moveSelectedLinesUp()
    }

    /// Moves the selected lines down by one line.
    ///
    /// Calling this function has no effect when the selected lines include the last line in the text view.
    public func moveSelectedLinesDown() {
        textInputView.moveSelectedLinesDown()
    }

    /// Attempts to detect the indent strategy used in the document. This may return an unknown strategy even
    /// when the document contains indentation.
    public func detectIndentStrategy() -> DetectedIndentStrategy {
        textInputView.detectIndentStrategy()
    }

    /// Go to the beginning of the line at the specified index.
    ///
    /// - Parameter lineIndex: Index of line to navigate to.
    /// - Parameter selection: The placement of the caret on the line.
    /// - Returns: True if the text view could navigate to the specified line index, otherwise false.
    @discardableResult
    public func goToLine(_ lineIndex: Int, select selection: GoToLineSelection = .beginning) -> Bool {
        guard lineIndex >= 0 && lineIndex < textInputView.lineManager.lineCount else {
            return false
        }
        // I'm not exactly sure why this is necessary but if the text view is the first responder as we jump
        // to the line and we don't resign the first responder first, the caret will disappear after we have
        // jumped to the specified line.
        resignFirstResponder()
        becomeFirstResponder()
        let line = textInputView.lineManager.line(atRow: lineIndex)
        textInputView.layoutLines(toLocation: line.location)
        scrollLocationToVisible(line.location)
        layoutIfNeeded()
        switch selection {
        case .beginning:
            textInputView.selectedRange = NSRange(location: line.location, length: 0)
        case .end:
            textInputView.selectedRange = NSRange(location: line.data.length, length: line.data.length)
        case .line:
            textInputView.selectedRange = NSRange(location: line.location, length: line.data.length)
        }
        return true
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
        let searchController = SearchController(stringView: textInputView.stringView)
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
        let searchController = SearchController(stringView: textInputView.stringView)
        searchController.delegate = self
        return searchController.search(for: query, replacingMatchesWith: replacementString)
    }

    /// Returns a peek into the text view's underlying attributed string.
    /// - Parameter range: Range of text to include in text view. The returned result may span a larger range than the one specified.
    /// - Returns: Text preview containing the specified range.
    public func textPreview(containing range: NSRange) -> TextPreview? {
        textInputView.textPreview(containing: range)
    }

    /// Selects a highlighted range behind the selected range if possible.
    public func selectPreviousHighlightedRange() {
        highlightNavigationController.selectPreviousRange()
    }

    /// Selects a highlighted range after the selected range if possible.
    public func selectNextHighlightedRange() {
        highlightNavigationController.selectNextRange()
    }

    /// Selects the highlighed range at the specified index.
    /// - Parameter index: Index of highlighted range to select.
    public func selectHighlightedRange(at index: Int) {
        highlightNavigationController.selectRange(at: index)
    }

    /// Synchronously displays the visible lines. This can be used to immediately update the visible lines after setting the theme. Use with caution as this redisplaying the visible lines can be a costly operation.
    public func redisplayVisibleLines() {
        textInputView.redisplayVisibleLines()
    }
}

// MARK: - UITextInput
extension TextView {
    /// The range of currently marked text in a document.
    public var markedTextRange: UITextRange? {
        textInputView.markedTextRange
    }

    /// The text position for the beginning of a document.
    public var beginningOfDocument: UITextPosition {
        textInputView.beginningOfDocument
    }

    /// The text position for the end of a document.
    public var endOfDocument: UITextPosition {
        textInputView.endOfDocument
    }

    /// Returns the range between two text positions.
    /// - Parameters:
    ///   - fromPosition: An object that represents a location in a document.
    ///   - toPosition: An object that represents another location in a document.
    /// - Returns: An object that represents the range between fromPosition and toPosition.
    public func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        textInputView.textRange(from: fromPosition, to: toPosition)
    }

    /// Returns the text position at a specified offset from another text position.
    /// - Parameters:
    ///   - position: A custom UITextPosition object that represents a location in a document.
    ///   - offset: A character offset from position. It can be a positive or negative value.
    /// - Returns: A custom UITextPosition object that represents the location in a document that is at the specified offset from position. Returns nil if the computed text position is less than 0 or greater than the length of the backing string.
    public func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        textInputView.position(from: position, offset: offset)
    }

    /// Returns the text position at a specified offset in a specified direction from another text position.
    /// - Parameters:
    ///   - position: A custom UITextPosition object that represents a location in a document.
    ///   - direction: A UITextLayoutDirection constant that represents the direction of the offset from position.
    ///   - offset: A character offset from position.
    /// - Returns: Returns the text position at a specified offset in a specified direction from another text position. Returns nil if the computed text position is less than 0 or greater than the length of the backing string.
    public func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        textInputView.position(from: position, in: direction, offset: offset)
    }

    /// Returns how one text position compares to another text position.
    /// - Parameters:
    ///   - position: A custom object that represents a location within a document.
    ///   - other: A custom object that represents another location within a document.
    /// - Returns: A value that indicates whether the two text positions are identical or whether one is before the other.
    public func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        textInputView.compare(position, to: other)
    }

    /// Returns the number of UTF-16 characters between one text position and another text position.
    /// - Parameters:
    ///   - from: A custom object that represents a location within a document.
    ///   - toPosition: A custom object that represents another location within document.
    /// - Returns: The number of UTF-16 characters between fromPosition and toPosition.
    public func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int {
        textInputView.offset(from: from, to: toPosition)
    }

    /// An input tokenizer that provides information about the granularity of text units.
    public var tokenizer: UITextInputTokenizer {
        textInputView.tokenizer
    }

    /// Returns the text position that is at the farthest extent in a specified layout direction within a range of text.
    /// - Parameters:
    ///   - range: A text-range object that demarcates a range of text in a document.
    ///   - direction: A constant that indicates a direction of layout (right, left, up, down).
    /// - Returns: A text-position object that identifies a location in the visible text.
    public func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        textInputView.position(within: range, farthestIn: direction)
    }

    /// Returns a text range from a specified text position to its farthest extent in a certain direction of layout.
    /// - Parameters:
    ///   - position: A text-position object that identifies a location in a document.
    ///   - direction: A constant that indicates a direction of layout (right, left, up, down).
    /// - Returns: A text-range object that represents the distance from position to the farthest extent in direction.
    public func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        textInputView.characterRange(byExtending: position, in: direction)
    }

    /// Returns the first rectangle that encloses a range of text in a document.
    /// - Parameter range: An object that represents a range of text in a document.
    /// - Returns: The first rectangle in a range of text. You might use this rectangle to draw a correction rectangle. The “first” in the name refers the rectangle enclosing the first line when the range encompasses multiple lines of text.
    public func firstRect(for range: UITextRange) -> CGRect {
        textInputView.firstRect(for: range)
    }

    /// Returns a rectangle to draw the caret at a specified insertion point.
    /// - Parameter position: An object that identifies a location in a text input area.
    /// - Returns: A rectangle that defines the area for drawing the caret.
    public func caretRect(for position: UITextPosition) -> CGRect {
        textInputView.caretRect(for: position)
    }

    /// Returns an array of selection rects corresponding to the range of text.
    /// - Parameter range: An object representing a range in a document’s text.
    /// - Returns: An array of UITextSelectionRect objects that encompass the selection.
    public func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        textInputView.selectionRects(for: range)
    }

    /// Returns the position in a document that is closest to a specified point.
    /// - Parameter point: A point in the view that is drawing a document’s text.
    /// - Returns: An object locating a position in a document that is closest to point.
    public func closestPosition(to point: CGPoint) -> UITextPosition? {
        textInputView.closestPosition(to: point)
    }

    /// Returns the position in a document that is closest to a specified point in a specified range.
    /// - Parameters:
    ///   - point: A point in the view that is drawing a document’s text.
    ///   - range: An object representing a range in a document’s text.
    /// - Returns: An object representing the character position in range that is closest to point.
    public func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        textInputView.closestPosition(to: point, within: range)
    }

    /// Returns the character or range of characters that is at a specified point in a document.
    /// - Parameter point: A point in the view that is drawing a document’s text.
    /// - Returns: An object representing a range that encloses a character (or characters) at point.
    public func characterRange(at point: CGPoint) -> UITextRange? {
        textInputView.characterRange(at: point)
    }

    /// Returns the text in the specified range.
    /// - Parameter range: A range of text in a document.
    /// - Returns: A substring of a document that falls within the specified range.
    public func text(in range: UITextRange) -> String? {
        textInputView.text(in: range)
    }

    /// A Boolean value that indicates whether the text-entry object has any text.
    public var hasText: Bool {
        textInputView.hasText
    }

    /// Scrolls the text view to reveal the text in the specified range.
    ///
    /// The function will scroll the text view as little as possible while revealing as much as possible of the specified range. It is not guaranteed that the entire range is visible after performing the scroll.
    ///
    /// - Parameters:
    ///   - range: The range of text to scroll into view.
    public func scrollRangeToVisible(_ range: NSRange) {
        textInputView.layoutLines(toLocation: range.upperBound)
        justScrollRangeToVisible(range)
    }
}

private extension TextView {
    @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard isSelectable else {
            return
        }
        if gestureRecognizer.state == .ended {
            let point = gestureRecognizer.location(in: textInputView)
            let oldSelectedRange = textInputView.selectedRange
            textInputView.moveCaret(to: point)
            if textInputView.selectedRange != oldSelectedRange {
                layoutIfNeeded()
            }
            installEditableInteraction()
            becomeFirstResponder()
        }
    }

    @objc private func handleTextRangeAdjustmentPan(_ gestureRecognizer: UIPanGestureRecognizer) {
        // This function scroll the text view when the selected range is adjusted.
        if gestureRecognizer.state == .began {
            previousSelectedRangeDuringGestureHandling = selectedRange
        } else if gestureRecognizer.state == .changed, let previousSelectedRange = previousSelectedRangeDuringGestureHandling {
            if selectedRange.lowerBound != previousSelectedRange.lowerBound {
                // User is adjusting the lower bound (location) of the selected range.
                scrollLocationToVisible(selectedRange.lowerBound)
            } else if selectedRange.upperBound != previousSelectedRange.upperBound {
                // User is adjusting the upper bound (length) of the selected range.
                scrollLocationToVisible(selectedRange.upperBound)
            }
            previousSelectedRangeDuringGestureHandling = selectedRange
        }
    }

    private func insertLeadingComponent(of characterPair: CharacterPair, in range: NSRange) -> Bool {
        let shouldInsertCharacterPair = editorDelegate?.textView(self, shouldInsert: characterPair, in: range) ?? true
        guard shouldInsertCharacterPair else {
            return false
        }
        guard let selectedRange = textInputView.selectedRange else {
            return false
        }
        if selectedRange.length == 0 {
            textInputView.insertText(characterPair.leading + characterPair.trailing)
            textInputView.selectedRange = NSRange(location: range.location + characterPair.leading.count, length: 0)
            return true
        } else if let text = textInputView.text(in: selectedRange) {
            let modifiedText = characterPair.leading + text + characterPair.trailing
            let indexedRange = IndexedRange(selectedRange)
            textInputView.replace(indexedRange, withText: modifiedText)
            textInputView.selectedRange = NSRange(location: range.location + characterPair.leading.count, length: range.length)
            return true
        } else {
            return false
        }
    }

    private func skipInsertingTrailingComponent(of characterPair: CharacterPair, in range: NSRange) -> Bool {
        // When typing the trailing component of a character pair, e.g. ) or } and the cursor is just in front of that character,
        // the delegate is asked whether the text view should skip inserting that character. If the character is skipped,
        // then the caret is moved after the trailing character component.
        let followingTextRange = NSRange(location: range.location + range.length, length: characterPair.trailing.count)
        let followingText = textInputView.text(in: followingTextRange)
        guard followingText == characterPair.trailing else {
            return false
        }
        let shouldSkip = editorDelegate?.textView(self, shouldSkipTrailingComponentOf: characterPair, in: range) ?? true
        if shouldSkip {
            moveCaret(byOffset: characterPair.trailing.count)
            return true
        } else {
            return false
        }
    }

    private func moveCaret(byOffset offset: Int) {
        if let selectedRange = textInputView.selectedRange {
            textInputView.selectedRange = NSRange(location: selectedRange.location + offset, length: 0)
        }
    }

    private func handleContentSizeUpdateIfNeeded() {
        if hasPendingContentSizeUpdate {
            // We don't want to update the content size when the scroll view is "bouncing" near the gutter,
            // or at the end of a line since it causes flickering when updating the content size while scrolling.
            // However, we do allow updating the content size if the text view is scrolled far enough on
            // the y-axis as that means it will soon run out of text to display.
            let isBouncingAtGutter = contentOffset.x < -contentInset.left
            let isBouncingAtLineEnd = contentOffset.x > contentSize.width - frame.size.width + contentInset.right
            let isBouncingHorizontally = isBouncingAtGutter || isBouncingAtLineEnd
            let isCriticalUpdate = contentOffset.y > contentSize.height - frame.height * 1.5
            let isScrolling = isDragging || isDecelerating
            if !isBouncingHorizontally || isCriticalUpdate || !isScrolling {
                hasPendingContentSizeUpdate = false
                let oldContentOffset = contentOffset
                contentSize = preferredContentSize
                contentOffset = oldContentOffset
                setNeedsLayout()
            }
        }
    }

    private func justScrollRangeToVisible(_ range: NSRange) {
        let lowerBoundRect = textInputView.caretRect(at: range.lowerBound)
        let upperBoundRect = range.length == 0 ? lowerBoundRect : textInputView.caretRect(at: range.upperBound)
        let rectMinX = min(lowerBoundRect.minX, upperBoundRect.minX)
        let rectMaxX = max(lowerBoundRect.maxX, upperBoundRect.maxX)
        let rectMinY = min(lowerBoundRect.minY, upperBoundRect.minY)
        let rectMaxY = max(lowerBoundRect.maxY, upperBoundRect.maxY)
        let rect = CGRect(x: rectMinX, y: rectMinY, width: rectMaxX - rectMinX, height: rectMaxY - rectMinY)
        contentOffset = contentOffsetForScrollingToVisibleRect(rect)
    }

    private func scrollLocationToVisible(_ location: Int) {
        let range = NSRange(location: location, length: 0)
        justScrollRangeToVisible(range)
    }

    private func installEditableInteraction() {
        if editableTextInteraction.view == nil {
            isInputAccessoryViewEnabled = true
            textInputView.removeInteraction(nonEditableTextInteraction)
            textInputView.addInteraction(editableTextInteraction)
            #if compiler(>=5.9)
            if #available(iOS 17, *) {
                // Workaround a bug where the caret does not appear until the user taps again on iOS 17 (FB12622609).
                textInputView.sbs_textSelectionDisplayInteraction?.isActivated = true
            }
            #endif
        }
    }

    private func installNonEditableInteraction() {
        if nonEditableTextInteraction.view == nil {
            isInputAccessoryViewEnabled = false
            textInputView.removeInteraction(editableTextInteraction)
            textInputView.addInteraction(nonEditableTextInteraction)
            for gestureRecognizer in nonEditableTextInteraction.gesturesForFailureRequirements {
                gestureRecognizer.require(toFail: tapGestureRecognizer)
            }
        }
    }

    /// Computes a content offset to scroll to in order to reveal the specified rectangle.
    ///
    /// The function will return a rectangle that scrolls the text view a minimum amount while revealing as much as possible of the rectangle. It is not guaranteed that the entire rectangle can be revealed.
    /// - Parameter rect: The rectangle to reveal.
    /// - Returns: The content offset to scroll to.
    private func contentOffsetForScrollingToVisibleRect(_ rect: CGRect) -> CGPoint {
        // Create the viewport: a rectangle containing the content that is visible to the user.
        var viewport = CGRect(x: contentOffset.x, y: contentOffset.y, width: frame.width, height: frame.height)
        viewport.origin.y += adjustedContentInset.top
        viewport.origin.x += adjustedContentInset.left + gutterWidth
        viewport.size.width -= adjustedContentInset.left + adjustedContentInset.right + gutterWidth
        viewport.size.height -= adjustedContentInset.top + adjustedContentInset.bottom
        // Construct the best possible content offset.
        var newContentOffset = contentOffset
        if rect.minX < viewport.minX {
            newContentOffset.x -= viewport.minX - rect.minX
        } else if rect.maxX > viewport.maxX && rect.width <= viewport.width {
            // The end of the rectangle is not visible and the rect fits within the screen so we'll scroll to reveal the entire rect.
            newContentOffset.x += rect.maxX - viewport.maxX
        } else if rect.maxX > viewport.maxX {
            newContentOffset.x += rect.minX
        }
        if rect.minY < viewport.minY {
            newContentOffset.y -= viewport.minY - rect.minY
        } else if rect.maxY > viewport.maxY && rect.height <= viewport.height {
            // The end of the rectangle is not visible and the rect fits within the screen so we'll scroll to reveal the entire rect.
            newContentOffset.y += rect.maxY - viewport.maxY
        } else if rect.maxY > viewport.maxY {
            newContentOffset.y += rect.minY
        }
        let cappedXOffset = min(max(newContentOffset.x, minimumContentOffset.x), maximumContentOffset.x)
        let cappedYOffset = min(max(newContentOffset.y, minimumContentOffset.y), maximumContentOffset.y)
        return CGPoint(x: cappedXOffset, y: cappedYOffset)
    }
}

// MARK: - TextInputViewDelegate
extension TextView: TextInputViewDelegate {
    func textInputViewWillBeginEditing(_ view: TextInputView) {
        guard isEditable else {
            return
        }
        isEditing = !isPerformingNonEditableTextInteraction
        // If a developer is programmatically calling becomeFirstresponder() then we might not have a selected range.
        // We set the selectedRange instead of the selectedTextRange to avoid invoking any delegates.
        if textInputView.selectedRange == nil && !isPerformingNonEditableTextInteraction {
            textInputView.selectedRange = NSRange(location: 0, length: 0)
        }
        // Ensure selection is laid out without animation.
        UIView.performWithoutAnimation {
            textInputView.layoutIfNeeded()
        }
        // The editable interaction must be installed early in the -becomeFirstResponder() call
        if !isPerformingNonEditableTextInteraction {
            installEditableInteraction()
        }
    }

    func textInputViewDidBeginEditing(_ view: TextInputView) {
        if !isPerformingNonEditableTextInteraction {
            editorDelegate?.textViewDidBeginEditing(self)
        }
    }

    func textInputViewDidCancelBeginEditing(_ view: TextInputView) {
        isEditing = false
        installNonEditableInteraction()
    }

    func textInputViewDidEndEditing(_ view: TextInputView) {
        isEditing = false
        installNonEditableInteraction()
        editorDelegate?.textViewDidEndEditing(self)
    }

    func textInputViewDidChange(_ view: TextInputView) {
        if isAutomaticScrollEnabled, let newRange = textInputView.selectedRange, newRange.length == 0 {
            scrollLocationToVisible(newRange.location)
        }
        editorDelegate?.textViewDidChange(self)
    }

    func textInputViewDidChangeSelection(_ view: TextInputView) {
        UIMenuController.shared.hideMenu(from: self)
        highlightNavigationController.selectedRange = view.selectedRange
        if isAutomaticScrollEnabled, let newRange = textInputView.selectedRange, newRange.length == 0 {
            scrollLocationToVisible(newRange.location)
        }
        editorDelegate?.textViewDidChangeSelection(self)
    }

    func textInputViewDidInvalidateContentSize(_ view: TextInputView) {
        if contentSize != view.contentSize {
            hasPendingContentSizeUpdate = true
            handleContentSizeUpdateIfNeeded()
        }
    }

    func textInputView(_ view: TextInputView, didProposeContentOffsetAdjustment contentOffsetAdjustment: CGPoint) {
        let isScrolling = isDragging || isDecelerating
        if contentOffsetAdjustment != .zero && isScrolling {
            contentOffset = CGPoint(x: contentOffset.x + contentOffsetAdjustment.x, y: contentOffset.y + contentOffsetAdjustment.y)
        }
    }

    func textInputView(_ view: TextInputView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if textInputView.isRestoringPreviouslyDeletedText {
            // UIKit is inserting text to combine characters, for example to combine two Korean characters into one, and we do not want to interfere with that.
            return editorDelegate?.textView(self, shouldChangeTextIn: range, replacementText: text) ?? true
        } else if let characterPair = characterPairs.first(where: { $0.trailing == text }),
                    skipInsertingTrailingComponent(of: characterPair, in: range) {
            return false
        } else if let characterPair = characterPairs.first(where: { $0.leading == text }), insertLeadingComponent(of: characterPair, in: range) {
            return false
        } else {
            return editorDelegate?.textView(self, shouldChangeTextIn: range, replacementText: text) ?? true
        }
    }

    func textInputViewDidChangeGutterWidth(_ view: TextInputView) {
        editorDelegate?.textViewDidChangeGutterWidth(self)
    }

    func textInputViewDidBeginFloatingCursor(_ view: TextInputView) {
        editorDelegate?.textViewDidBeginFloatingCursor(self)
    }

    func textInputViewDidEndFloatingCursor(_ view: TextInputView) {
        editorDelegate?.textViewDidEndFloatingCursor(self)
    }

    func textInputViewDidUpdateMarkedRange(_ view: TextInputView) {
        // There seems to be a bug in UITextInput (or UITextInteraction?) where updating the markedTextRange of a UITextInput
        // will cause the caret to disappear. Removing the editable text interaction and adding it back will work around this issue.
        DispatchQueue.main.async {
            if !view.viewHierarchyContainsCaret && self.editableTextInteraction.view != nil {
                view.removeInteraction(self.editableTextInteraction)
                view.addInteraction(self.editableTextInteraction)
                #if compiler(>=5.9)
                if #available(iOS 17, *) {
                    self.textInputView.sbs_textSelectionDisplayInteraction?.isActivated = true
                    self.textInputView.sbs_textSelectionDisplayInteraction?.sbs_enableCursorBlinks()
                }
                #endif
            }
        }
    }

    func textInputView(_ view: TextInputView, canReplaceTextIn highlightedRange: HighlightedRange) -> Bool {
        editorDelegate?.textView(self, canReplaceTextIn: highlightedRange) ?? false
    }

    func textInputView(_ view: TextInputView, replaceTextIn highlightedRange: HighlightedRange) {
        editorDelegate?.textView(self, replaceTextIn: highlightedRange)
    }
}

// MARK: - HighlightNavigationControllerDelegate
extension TextView: HighlightNavigationControllerDelegate {
    func highlightNavigationController(_ controller: HighlightNavigationController,
                                       shouldNavigateTo highlightNavigationRange: HighlightNavigationRange) {
        let range = highlightNavigationRange.range
        scrollRangeToVisible(range)
        textInputView.selectedTextRange = IndexedRange(range)
        _ = textInputView.becomeFirstResponder()
        if showMenuAfterNavigatingToHighlightedRange {
            textInputView.presentEditMenuForText(in: range)
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

// MARK: - SearchControllerDelegate
extension TextView: SearchControllerDelegate {
    func searchController(_ searchController: SearchController, linePositionAt location: Int) -> LinePosition? {
        textInputView.lineManager.linePosition(at: location)
    }
}

// MARK: - UIGestureRecognizerDelegate
extension TextView: UIGestureRecognizerDelegate {
    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === tapGestureRecognizer {
            return !isEditing && !isDragging && !isDecelerating && delegateAllowsEditingToBegin
        } else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
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
    func keyboardObserver(_ keyboardObserver: KeyboardObserver,
                          keyboardWillShowWithHeight keyboardHeight: CGFloat,
                          animation: KeyboardObserver.Animation?) {
        if isAutomaticScrollEnabled, let newRange = textInputView.selectedRange, newRange.length == 0 {
            scrollRangeToVisible(newRange)
        }
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
// swiftlint:enable type_body_length
