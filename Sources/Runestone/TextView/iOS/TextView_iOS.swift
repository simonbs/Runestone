#if os(iOS)
// swiftlint:disable file_length type_body_length
import Combine
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
    public weak var editorDelegate: TextViewDelegate? {
        get {
            textViewDelegate.delegate
        }
        set {
            textViewDelegate.delegate = newValue
        }
    }
    /// An input delegate that receives a notification when text changes or when the selection changes.
    @objc public weak var inputDelegate: UITextInputDelegate?
    /// Returns a Boolean value indicating whether this object can become the first responder.
    override public var canBecomeFirstResponder: Bool {
        !isFirstResponder && isEditable
    }
    /// A Boolean value that indicates whether the text view is editable.
    @_RunestoneProxy(\TextView.editorState.isEditable.value)
    public var isEditable: Bool
    /// A Boolean value that indicates whether the text view is selectable.
    @_RunestoneProxy(\TextView.editorState.isSelectable.value)
    public var isSelectable: Bool
    /// Whether the text view is in a state where the contents can be edited.
    public var isEditing: Bool {
        editorState.isEditing.value
    }
    /// The text that the text view displays.
    public var text: String {
        get {
            stringView.value.string as String
        }
        set {
            textSetter.setText(newValue as NSString)
        }
    }
    /// The view's background color.
    open override var backgroundColor: UIColor? {
        didSet {
            if backgroundColor != oldValue {
                textViewBackgroundColor.value = backgroundColor
            }
        }
    }
    /// Colors and fonts to be used by the editor.
    @_RunestoneProxy(\TextView.themeSettings.theme.value)
    public var theme: Theme
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
    /// Character pairs are used by the editor to automatically insert a trailing character when the user types the leading character.
    ///
    /// Common usages of this includes the \" character to surround strings and { } to surround a scope.
    @_RunestoneProxy(\TextView.characterPairService.characterPairs)
    public var characterPairs: [CharacterPair]
    /// Determines what should happen to the trailing component of a character pair when deleting the leading component. Defaults to `disabled` meaning that nothing will happen.
    @_RunestoneProxy(\TextView.characterPairService.trailingComponentDeletionMode)
    public var characterPairTrailingComponentDeletionMode: CharacterPairTrailingComponentDeletionMode
    /// Enable to show line numbers in the gutter.
//    public var showLineNumbers: Bool {
//        get {
//            showLineNumbers
//        }
//        set {
//            showLineNumbers = newValue
//        }
//    }
    /// Enable to show highlight the selected lines. The selection is only shown in the gutter when multiple lines are selected.
    @_RunestoneProxy(\TextView.lineSelectionLayouter.lineSelectionDisplayType.value)
    public var lineSelectionDisplayType: LineSelectionDisplayType
    /// The text view renders invisible tabs when enabled. The `tabsSymbol` is used to render tabs.
    @_RunestoneProxy(\TextView.invisibleCharacterSettings.showTabs.value)
    public var showTabs: Bool
    /// The text view renders invisible spaces when enabled.
    ///
    /// The `spaceSymbol` is used to render spaces.
    @_RunestoneProxy(\TextView.invisibleCharacterSettings.showSpaces.value)
    public var showSpaces: Bool
    /// The text view renders invisible spaces when enabled.
    ///
    /// The `nonBreakingSpaceSymbol` is used to render spaces.
    @_RunestoneProxy(\TextView.invisibleCharacterSettings.showNonBreakingSpaces.value)
    public var showNonBreakingSpaces: Bool
    /// The text view renders invisible line breaks when enabled.
    ///
    /// The `lineBreakSymbol` is used to render line breaks.
    @_RunestoneProxy(\TextView.invisibleCharacterSettings.showLineBreaks.value)
    public var showLineBreaks: Bool
    /// The text view renders invisible soft line breaks when enabled.
    ///
    /// The `softLineBreakSymbol` is used to render line breaks. These line breaks are typically represented by the U+2028 unicode character. Runestone does not provide any key commands for inserting these but supports rendering them.
    @_RunestoneProxy(\TextView.invisibleCharacterSettings.showSoftLineBreaks.value)
    public var showSoftLineBreaks: Bool
    /// Symbol used to display tabs.
    ///
    /// The value is only used when invisible tab characters is enabled. The default is ▸.
    ///
    /// Common characters for this symbol include ▸, ⇥, ➜, ➞, and ❯.
    @_RunestoneProxy(\TextView.invisibleCharacterSettings.tabSymbol.value)
    public var tabSymbol: String
    /// Symbol used to display spaces.
    ///
    /// The value is only used when showing invisible space characters is enabled. The default is ·.
    ///
    /// Common characters for this symbol include ·, •, and _.
    @_RunestoneProxy(\TextView.invisibleCharacterSettings.spaceSymbol.value)
    public var spaceSymbol: String
    /// Symbol used to display non-breaking spaces.
    ///
    /// The value is only used when showing invisible space characters is enabled. The default is ·.
    ///
    /// Common characters for this symbol include ·, •, and _.
    @_RunestoneProxy(\TextView.invisibleCharacterSettings.nonBreakingSpaceSymbol.value)
    public var nonBreakingSpaceSymbol: String
    /// Symbol used to display line break.
    ///
    /// The value is only used when showing invisible line break characters is enabled. The default is ¬.
    ///
    /// Common characters for this symbol include ¬, ↵, ↲, ⤶, and ¶.
    @_RunestoneProxy(\TextView.invisibleCharacterSettings.lineBreakSymbol.value)
    public var lineBreakSymbol: String
    /// Symbol used to display soft line breaks.
    ///
    /// The value is only used when showing invisible soft line break characters is enabled. The default is ¬.
    ///
    /// Common characters for this symbol include ¬, ↵, ↲, ⤶, and ¶.
    @_RunestoneProxy(\TextView.invisibleCharacterSettings.softLineBreakSymbol.value)
    public var softLineBreakSymbol: String
    /// The strategy used when indenting text.
    @_RunestoneProxy(\TextView.typesetSettings.indentStrategy.value)
    public var indentStrategy: IndentStrategy
    /// The amount of padding before the line numbers inside the gutter.
//    public var gutterLeadingPadding: CGFloat {
//        get {
//            gutterLeadingPadding
//        }
//        set {
//            gutterLeadingPadding = newValue
//        }
//    }
    /// The amount of padding after the line numbers inside the gutter.
//    public var gutterTrailingPadding: CGFloat {
//        get {
//            gutterTrailingPadding
//        }
//        set {
//            gutterTrailingPadding = newValue
//        }
//    }
    /// The minimum amount of characters to use for width calculation inside the gutter.
//    public var gutterMinimumCharacterCount: Int {
//        get {
//            gutterMinimumCharacterCount
//        }
//        set {
//            gutterMinimumCharacterCount = newValue
//        }
//    }
    /// The amount of spacing surrounding the lines.
    @_RunestoneProxy(\TextView.textContainer.inset.value)
    public var textContainerInset: UIEdgeInsets
    /// When line wrapping is disabled, users can scroll the text view horizontally to see the entire line.
    ///
    /// Line wrapping is enabled by default.
    @_RunestoneProxy(\TextView.typesetSettings.isLineWrappingEnabled.value)
    public var isLineWrappingEnabled: Bool
    /// Line break mode for text view. The default value is .byWordWrapping meaning that wrapping occurs on word boundaries.
    @_RunestoneProxy(\TextView.typesetSettings.lineBreakMode.value)
    public var lineBreakMode: LineBreakMode
    /// Width of the gutter.
//    public var gutterWidth: CGFloat {
//        gutterWidthService.gutterWidth
//    }
    /// The line-height is multiplied with the value.
    @_RunestoneProxy(\TextView.typesetSettings.lineHeightMultiplier.value)
    public var lineHeightMultiplier: CGFloat
    /// The number of points by which to adjust kern. The default value is 0 meaning that kerning is disabled.
    @_RunestoneProxy(\TextView.typesetSettings.kern.value)
    public var kern: CGFloat
    /// The text view shows a page guide when enabled. Use `pageGuideColumn` to specify the location of the page guide.
    @_RunestoneProxy(\TextView.pageGuideLayouter.isEnabled)
    public var showPageGuide: Bool
    /// Specifies the location of the page guide. Use `showPageGuide` to specify if the page guide should be shown.
    @_RunestoneProxy(\TextView.pageGuideLayouter.column)
    public var pageGuideColumn: Int
    /// Automatically scrolls the text view to show the caret when typing or moving the caret.
    @_RunestoneProxy(\TextView.automaticViewportScroller.isAutomaticScrollEnabled)
    public var isAutomaticScrollEnabled: Bool
    /// Amount of overscroll to add in the vertical direction.
    ///
    /// The overscroll is a factor of the scrollable area height and will not take into account any insets. 0 means no overscroll and 1 means an amount equal to the height of the text view. Detaults to 0.
    @_RunestoneProxy(\TextView.contentSizeService.verticalOverscrollFactor.value)
    public var verticalOverscrollFactor: CGFloat
    /// Amount of overscroll to add in the horizontal direction.
    ///
    /// The overscroll is a factor of the scrollable area height and will not take into account any insets or the width of the gutter. 0 means no overscroll and 1 means an amount equal to the width of the text view. Detaults to 0.
    @_RunestoneProxy(\TextView.contentSizeService.horizontalOverscrollFactor.value)
    public var horizontalOverscrollFactor: CGFloat
    /// The length of the line that was longest when opening the document.
    ///
    /// This will return nil if the line is no longer available. The value will not be kept updated as the text is changed. The value can be used to determine if a document contains a very long line in which case the performance may be degraded when editing the line.
    public var lengthOfInitallyLongestLine: Int? {
        lineManager.value.initialLongestLine?.data.totalLength
    }
    /// Ranges in the text to be highlighted. The color defined by the background will be drawen behind the text.
    @_RunestoneProxy(\TextView.highlightedRangeFragmentStore.highlightedRanges.value)
    public var highlightedRanges: [HighlightedRange]
    /// Wheter the text view should loop when navigating through highlighted ranges using `selectPreviousHighlightedRange` or `selectNextHighlightedRange` on the text view.
    @_RunestoneProxy(\TextView.highlightedRangeNavigator.loopingMode)
    public var highlightedRangeLoopingMode: HighlightedRangeLoopingMode
    /// Line endings to use when inserting a line break.
    ///
    /// The value only affects new line breaks inserted in the text view and changing this value does not change the line endings of the text in the text view. Defaults to Unix (LF).
    ///
    /// The TextView will only update the line endings when text is modified through an external event, such as when the user typing on the keyboard, when the user is replacing selected text, and when pasting text into the text view. In all other cases, you should make sure that the text provided to the text view uses the desired line endings. This includes when calling ``TextView/setState(_:addUndoAction:)``.
    @_RunestoneProxy(\TextView.typesetSettings.lineEndings.value)
    public var lineEndings: LineEnding
    /// The shape of the insertion point.
    ///
    /// Defaults to ``InsertionPointShape/verticalBar``.
    @_RunestoneProxy(\TextView.insertionPointShapeSubject.value)
    public var insertionPointShape: InsertionPointShape
    /// The insertion point's visibility mode.
    ///
    /// Defaults to ``InsertionPointVisibilityMode/whenMovingAndFarAway``.
    @_RunestoneProxy(\TextView.insertionPointVisibilityModeSubject.value)
    public var insertionPointVisibilityMode: InsertionPointVisibilityMode
    /// The color of the insertion point.
    ///
    /// This can be used to control the color of the caret.
    @_RunestoneProxy(\TextView.insertionPointBackgroundColorSubject.value)
    @objc public var insertionPointColor: UIColor {
        didSet {
            if insertionPointColor != oldValue {
                textSelectionViewManager.updateInsertionPointColor()
            }
        }
    }
    /// The color of the insertion point when it is being moved.
    ///
    /// The insertion point assumes this color when it is being moved to depict where the insertion point will be placed when the moving operation ends.
    @_RunestoneProxy(\TextView.insertionPointPlaceholderBackgroundColorSubject.value)
    public var insertionPointPlaceholderBackgroundColor: UIColor
    /// The color of the insertion point.
    ///
    /// This can be used to control the color of the caret.
    @_RunestoneProxy(\TextView.insertionPointTextColorSubject.value)
    public var insertionPointForegroundColor: UIColor
    /// The color of the insertion point.
    ///
    /// This can be used to control the color of the caret.
    @_RunestoneProxy(\TextView.insertionPointInvisibleCharacterColorSubject.value)
    public var insertionPointInvisibleCharacterForegroundColor: UIColor
    /// The color of the selection bar.
    ///
    /// It is most common to set this to the same color as the color used for the insertion point.
    @objc public var selectionBarColor: UIColor = .label
    /// The color of the selection highlight.
    ///
    /// It is most common to set this to the same color as the color used for the insertion point.
    @objc public var selectionHighlightColor: UIColor = .label.withAlphaComponent(0.2)
    /// The object that the document uses to support undo/redo operations.
    override open var undoManager: UndoManager? {
        _undoManager
    }
    /// When enabled the text view will present a menu with actions actions such as Copy and Replace after navigating to a highlighted range.
    @_RunestoneProxy(\TextView.highlightedRangeNavigator.showMenuAfterNavigatingToHighlightedRange)
    public var showMenuAfterNavigatingToHighlightedRange: Bool
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
    /// The behavior of inline text predictions for a text-entry area.
    @available(iOS 17, *)
    public var inlinePredictionType: UITextInlinePredictionType {
        get {
            UITextInlinePredictionType(_inlinePredictionType)
        }
        set {
            _inlinePredictionType = TextInlinePredictionType(newValue)
        }
    }
    private var _inlinePredictionType: TextInlinePredictionType = .default
    /// An affiliated view that provides a coordinate system for all geometric values in the protocol.
    ///
    /// This property returns the instance of `TextView` that holds the property.
    public var textInputView: UIView {
        self
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

//    private let textSearchingHelper: UITextSearchingHelper
//    private let editMenuController = EditMenuController()
//    private let keyboardObserver = KeyboardObserver()
    private var isInputAccessoryViewEnabled = false
    private var _inputAccessoryView: UIView?
    private let beginEditingGestureRecognizer: UIGestureRecognizer
    private var isPerformingNonEditableTextInteraction = false
    private var shouldBeginEditing: Bool {
        isEditable && (editorDelegate?.textViewShouldBeginEditing(self) ?? true)
    }
    private var shouldEndEditing: Bool {
        editorDelegate?.textViewShouldEndEditing(self) ?? true
    }

    private let _scrollView: CurrentValueSubject<WeakBox<MultiPlatformScrollView>, Never>
    private let textViewDelegate: ErasedTextViewDelegate
    private let _isFirstResponder: CurrentValueSubject<Bool, Never>
    private let textInteractionManager: UITextInteractionManager
    private let textViewNeedsLayoutObserver: TextViewNeedsLayoutObserver
    private var boundsObserver: AnyCancellable?

    let textInputHelper: UITextInputHelper
    private let textRangeAdjustmentGestureTracker: UITextRangeAdjustmentGestureTracker

    let stringView: CurrentValueSubject<StringView, Never>
    private let lineManager: CurrentValueSubject<LineManager, Never>

    private let selectedRangeSubject: CurrentValueSubject<NSRange, Never>
    private let markedRangeSubject: CurrentValueSubject<NSRange?, Never>

    private let textContainer: TextContainer
    private let typesetSettings: TypesetSettings
    private let invisibleCharacterSettings: InvisibleCharacterSettings
    private let themeSettings: ThemeSettings
    private let textViewBackgroundColor: CurrentValueSubject<MultiPlatformColor?, Never>

    private let _undoManager: UndoManager
    private let characterPairService: CharacterPairService
    let indentationChecker: IndentationChecker

    let languageMode: CurrentValueSubject<any InternalLanguageMode, Never>
    let languageModeSetter: LanguageModeSetter

    private let textSetter: TextSetter
    let textViewStateSetter: TextViewStateSetter

    private let editorState: EditorState
    let textReplacer: TextReplacer
    let textShifter: TextShifter

    private let contentSizeService: ContentSizeService

    private let locationRaycaster: LocationRaycaster
    let lineMover: LineMover
    let goToLineNavigator: GoToLineNavigator
    let syntaxNodeRaycaster: SyntaxNodeRaycaster
    let textLocationConverter: TextLocationConverter

    private let insertionPointLayouter: InsertionPointLayouter
    private let lineFragmentLayouter: LineFragmentLayouter
    private let lineSelectionLayouter: LineSelectionLayouter
    private let pageGuideLayouter: PageGuideLayouter

    private let insertionPointShapeSubject: CurrentValueSubject<InsertionPointShape, Never>
    private let insertionPointVisibilityModeSubject: CurrentValueSubject<InsertionPointVisibilityMode, Never>
    private let insertionPointBackgroundColorSubject: CurrentValueSubject<MultiPlatformColor, Never>
    private let insertionPointPlaceholderBackgroundColorSubject: CurrentValueSubject<MultiPlatformColor, Never>
    private let insertionPointTextColorSubject: CurrentValueSubject<MultiPlatformColor, Never>
    private let insertionPointInvisibleCharacterColorSubject: CurrentValueSubject<MultiPlatformColor, Never>

    let viewportScroller: ViewportScroller
    private let automaticViewportScroller: AutomaticViewportScroller

    private let textSearchingHelper: UITextSearchingHelper
    let searchService: SearchService
    let batchReplacer: BatchReplacer
    let textPreviewFactory: TextPreviewFactory

    private let highlightedRangeFragmentStore: HighlightedRangeFragmentStore
    let highlightedRangeNavigator: HighlightedRangeNavigator

    private let textSelectionViewManager: UITextSelectionViewManager

    private let pressesHandler: PressesHandler

    /// Create a new text view.
    /// - Parameter frame: The frame rectangle of the text view.
    override public init(frame: CGRect) {
        let compositionRoot = CompositionRoot()
        _scrollView = compositionRoot.scrollView
        textViewDelegate = compositionRoot.textViewDelegate
        _isFirstResponder = compositionRoot.isFirstResponder
        textInteractionManager = compositionRoot.textInteractionManager
        textViewNeedsLayoutObserver = compositionRoot.textViewNeedsLayoutObserver
        beginEditingGestureRecognizer = compositionRoot.beginEditingGestureRecognizer

        textInputHelper = compositionRoot.textInputHelper
        textRangeAdjustmentGestureTracker = compositionRoot.textRangeAdjustmentGestureTracker

        stringView = compositionRoot.stringView
        lineManager = compositionRoot.lineManager

        selectedRangeSubject = compositionRoot.selectedRange
        markedRangeSubject = compositionRoot.markedRange

        textContainer = compositionRoot.textContainer
        typesetSettings = compositionRoot.typesetSettings
        invisibleCharacterSettings = compositionRoot.invisibleCharacterSettings
        themeSettings = compositionRoot.themeSettings
        textViewBackgroundColor = compositionRoot.textViewBackgroundColor

        _undoManager = compositionRoot.undoManager
        characterPairService = compositionRoot.characterPairService
        indentationChecker = compositionRoot.indentationChecker

        languageMode = compositionRoot.languageMode
        languageModeSetter = compositionRoot.languageModeSetter

        textSetter = compositionRoot.textSetter
        textViewStateSetter = compositionRoot.textViewStateSetter

        editorState = compositionRoot.editorState
        textReplacer = compositionRoot.textReplacer
        textShifter = compositionRoot.textShifter

        contentSizeService = compositionRoot.contentSizeService

        locationRaycaster = compositionRoot.locationRaycaster
        lineMover = compositionRoot.lineMover
        goToLineNavigator = compositionRoot.goToLineNavigator
        syntaxNodeRaycaster = compositionRoot.syntaxNodeRaycaster
        textLocationConverter = compositionRoot.textLocationConverter

        insertionPointLayouter = compositionRoot.insertionPointLayouter
        lineFragmentLayouter = compositionRoot.lineFragmentLayouter
        lineSelectionLayouter = compositionRoot.lineSelectionLayouter
        pageGuideLayouter = compositionRoot.pageGuideLayouter

        insertionPointShapeSubject = compositionRoot.insertionPointShape
        insertionPointVisibilityModeSubject = compositionRoot.insertionPointVisibilityMode
        insertionPointBackgroundColorSubject = compositionRoot.insertionPointBackgroundColor
        insertionPointPlaceholderBackgroundColorSubject = compositionRoot.insertionPointPlaceholderBackgroundColor
        insertionPointTextColorSubject = compositionRoot.insertionPointTextColor
        insertionPointInvisibleCharacterColorSubject = compositionRoot.insertionPointInvisibleCharacterColor

        viewportScroller = compositionRoot.viewportScroller
        automaticViewportScroller = compositionRoot.automaticViewportScroller

        textSearchingHelper = compositionRoot.textSearchingHelper
        searchService = compositionRoot.searchService
        batchReplacer = compositionRoot.batchReplacer
        textPreviewFactory = compositionRoot.textPreviewFactory

        highlightedRangeFragmentStore = compositionRoot.highlightedRangeFragmentStore
        highlightedRangeNavigator = compositionRoot.highlightedRangeNavigator

        textSelectionViewManager = compositionRoot.textSelectionViewManager

        pressesHandler = compositionRoot.pressesHandler
        super.init(frame: frame)
        compositionRoot.textView.value = WeakBox(self)
        backgroundColor = .white
        beginEditingGestureRecognizer.delegate = self
        beginEditingGestureRecognizer.addTarget(self, action: #selector(handleTap(_:)))
        addGestureRecognizer(beginEditingGestureRecognizer)
        textInteractionManager.installNonEditableInteraction()
        textInputHelper.tokenizer = compositionRoot.textInputStringTokenizer(for: self)

//        keyboardObserver.delegate = self
//        textSearchingHelper.textView = self
//        editMenuController.delegate = self
//        editMenuController.setupEditMenu(in: self)
//        textViewController.highlightedRangeNavigator.delegate = self
    }

    /// The initializer has not been implemented.
    /// - Parameter coder: Not used.
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Lays out subviews.
    override open func layoutSubviews() {
        super.layoutSubviews()
        textInputHelper.resetHasDeletedTextWithPendingLayoutSubviews()
        textInputHelper.notifyInputDelegateFromLayoutSubviewsIfNeeded()
        contentSizeService.updateContentSizeIfNeeded()
        textContainer.viewport.value = CGRect(origin: contentOffset, size: frame.size)
        lineFragmentLayouter.layoutIfNeeded()
    }

    /// Called when the safe area of the view changes.
    override open func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        textContainer.safeAreaInsets.value = safeAreaInsets
        layoutIfNeeded()
    }

    /// Asks UIKit to make this object the first responder in its window.
    @discardableResult
    override open func becomeFirstResponder() -> Bool {
        guard !editorState.isEditing.value && shouldBeginEditing else {
            return false
        }
        if canBecomeFirstResponder {
            willBeginEditing()
        }
        let didBecomeFirstResponder = super.becomeFirstResponder()
        if didBecomeFirstResponder {
            _isFirstResponder.value = true
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
            _isFirstResponder.value = false
            didEndEditing()
        }
        return didResignFirstResponder
    }
//
//    /// Replace the selected range with the specified text.
//    ///
//    /// - Parameter obj: Text to replace the selected range with.
//    @objc func replace(_ obj: NSObject) {
//        /// When autocorrection is enabled and the user tap on a misspelled word, UITextInteraction will present
//        /// a UIMenuController with suggestions for the correct spelling of the word. Selecting a suggestion will
//        /// cause UITextInteraction to call the non-existing -replace(_:) function and pass an instance of the private
//        /// UITextReplacement type as parameter. We can't make autocorrection work properly without using private API.
//        if let replacementText = obj.value(forKey: "_repl" + "Ttnemeca".reversed() + "ext") as? String {
//            if let indexedRange = obj.value(forKey: "_r" + "gna".reversed() + "e") as? IndexedRange {
//                replace(indexedRange, withText: replacementText)
//            }
//        }
//    }
//
//    /// Requests the receiving responder to enable or disable the specified command in the user interface.
//    /// - Parameters:
//    ///   - action: A selector that identifies a method associated with a command.
//    ///   - sender: The object calling this method.
//    /// - Returns: true if the command identified by action should be enabled or false if it should be disabled.
//    override open func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
//        if action == #selector(copy(_:)) {
//            if let selectedTextRange = selectedTextRange {
//                return !selectedTextRange.isEmpty
//            } else {
//                return false
//            }
//        } else if action == #selector(cut(_:)) {
//            if let selectedTextRange = selectedTextRange {
//                return isEditing && !selectedTextRange.isEmpty
//            } else {
//                return false
//            }
//        } else if action == #selector(paste(_:)) {
//            return isEditing && UIPasteboard.general.hasStrings
//        } else if action == #selector(selectAll(_:)) {
//            return true
//        } else if action == #selector(replace(_:)) {
//            return true
//        } else if action == NSSelectorFromString("replaceTextInSelectedHighlightedRange") {
//            if let selectedRange = textViewController.selectedRange,
//               let highlightedRange = highlightedRanges.first(where: { $0.range == selectedRange.value }) {
//                return editorDelegate?.textView(self, canReplaceTextIn: highlightedRange) ?? false
//            } else {
//                return false
//            }
//        } else {
//            return super.canPerformAction(action, withSender: sender)
//        }
//    }
//
//    /// Called when the iOS interface environment changes.
//    override open func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
//        super.traitCollectionDidChange(previousTraitCollection)
//        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
//            textViewController.invalidateLines()
//            textViewController.lineFragmentLayouter.setNeedsLayout()
//        }
//    }
//
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
        pressesHandler.handlePressesEnded(presses, with: event)
    }
}

//extension TextView {
//    private func handleTextSelectionChange() {
//        UIMenuController.shared.hideMenu(from: self)
//        scrollToVisibleLocationIfNeeded()
//    }
//
//    func sendSelectionChangedToTextSelectionView() {
//        // The only way I've found to get the selection change to be reflected properly while still supporting Korean, Chinese, and deleting words with Option+Backspace is to call a private API in some cases. However, as pointed out by Alexander Blach in the following PR, there is another workaround to the issue.
//        // When passing nil to the input delegate, the text selection is updated but the text input ignores it.
//        // Even the Swift Playgrounds app does not get this right for all languages in all cases, so there seems to be some workarounds needed due bugs in internal classes in UIKit that communicate with instances of UITextInput.
//        inputDelegate?.selectionDidChange(nil)
//    }
//
//}

private extension TextView {
    private func willBeginEditing() {
        guard isEditable else {
            return
        }
        editorState.isEditing.value = !isPerformingNonEditableTextInteraction
        // If a developer is programmatically calling becomeFirstResponder() then we might not have a selected range.
        // We set the selectedRange instead of the selectedTextRange to avoid invoking any delegates.
//        if textViewController.selectedRange == nil && !isPerformingNonEditableTextInteraction {
//            textViewController.selectedRange = NSRange(location: 0, length: 0)
//        }
        // Ensure selection is laid out without animation.
        UIView.performWithoutAnimation {
            layoutIfNeeded()
        }
        // The editable interaction must be installed early in the -becomeFirstResponder() call
        if !isPerformingNonEditableTextInteraction {
            textInteractionManager.installEditableInteraction()
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
        editorState.isEditing.value = false
        textInteractionManager.installEditableInteraction()
    }

    private func didEndEditing() {
        editorState.isEditing.value = false
        textInteractionManager.installNonEditableInteraction()
        editorDelegate?.textViewDidEndEditing(self)
    }

    @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        guard editorState.isSelectable.value, gestureRecognizer.state == .ended else {
            return
        }
        let point = gestureRecognizer.location(in: self)
        let oldSelectedRange = selectedRangeSubject.value
        let index = locationRaycaster.location(closestTo: point)
        selectedRangeSubject.value = NSRange(location: index, length: 0)
        if selectedRangeSubject.value != oldSelectedRange {
            layoutIfNeeded()
        }
        textInteractionManager.installEditableInteraction()
        becomeFirstResponder()
    }

//    @objc private func replaceTextInSelectedHighlightedRange() {
//        guard let selectedRange = textViewController.selectedRange else {
//            return
//        }
//        guard let highlightedRange = highlightedRanges.first(where: { $0.range == selectedRange }) else {
//            return
//        }
//        editorDelegate?.textView(self, replaceTextIn: highlightedRange)
//    }
//
//    private func handleKeyPressDuringMultistageTextInput(keyCode: UIKeyboardHIDUsage) {
//        // When editing multistage text input (that is, we have a marked text) we let the user unmark the text
//        // by pressing the arrow keys or Escape. This isn't common in iOS apps but it's the default behavior
//        // on macOS and I think that works quite well for plain text editors on iOS too.
//        guard let markedRange = textViewController.markedRange, let markedText = textViewController.stringView.substring(in: markedRange) else {
//            return
//        }
//        // We only unmark the text if the marked text contains specific characters only.
//        // Some languages use multistage text input extensively and for those iOS presents a UI when
//        // navigating with the arrow keys. We do not want to interfere with that interaction.
//        let characterSet = CharacterSet(charactersIn: "`´^¨")
//        guard markedText.rangeOfCharacter(from: characterSet.inverted) == nil else {
//            return
//        }
//        switch keyCode {
//        case .keyboardUpArrow:
//            textViewController.moveUp()
//            unmarkText()
//        case .keyboardRightArrow:
//            textViewController.moveRight()
//            unmarkText()
//        case .keyboardDownArrow:
//            textViewController.moveDown()
//            unmarkText()
//        case .keyboardLeftArrow:
//            textViewController.moveLeft()
//            unmarkText()
//        case .keyboardEscape:
//            unmarkText()
//        default:
//            break
//        }
//    }
//
//    private func scrollToVisibleLocationIfNeeded() {
//        if isAutomaticScrollEnabled, let newRange = textViewController.selectedRange, newRange.length == 0 {
//            textViewController.scrollLocationToVisible(newRange.location)
//        }
//    }
}

// MARK: - TextViewControllerDelegate
//extension TextView: TextViewControllerDelegate {
//    func textViewControllerDidChangeText(_ textViewController: TextViewController) {
//        editorDelegate?.textViewDidChange(self)
//    }
//
//    func textViewController(_ textViewController: TextViewController, didChangeSelectedRange selectedRange: NSRange?) {
//        UIMenuController.shared.hideMenu(from: self)
//        scrollToVisibleLocationIfNeeded()
//        editorDelegate?.textViewDidChangeSelection(self)
//    }
//}

// MARK: - SearchControllerDelegate
//extension TextView: SearchControllerDelegate {
//    func searchController(_ searchController: SearchController, linePositionAt location: Int) -> LinePosition? {
//        textViewController.lineManager.linePosition(at: location)
//    }
//}

// MARK: - UIGestureRecognizerDelegate
extension TextView: UIGestureRecognizerDelegate {
    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === beginEditingGestureRecognizer {
            return !isEditing && !isDragging && !isDecelerating && shouldBeginEditing
        } else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        textRangeAdjustmentGestureTracker.beginTrackingGestureRecognizerIfNeeded(gestureRecognizer)
        return gestureRecognizer !== panGestureRecognizer
    }
}

// MARK: - KeyboardObserverDelegate
//extension TextView: KeyboardObserverDelegate {
//    func keyboardObserver(
//        _ keyboardObserver: KeyboardObserver,
//        keyboardWillShowWithHeight keyboardHeight: CGFloat,
//        animation: KeyboardObserver.Animation?
//    ) {
//        scrollToVisibleLocationIfNeeded()
//    }
//}

// MARK: - EditMenuControllerDelegate
//extension TextView: EditMenuControllerDelegate {
//    func editMenuController(_ controller: EditMenuController, caretAt location: Int) -> CGRect {
//        let caretFactory = CaretFactory(
//            stringView: textViewController.stringView,
//            lineManager: textViewController.lineManager,
//            lineControllerStorage: textViewController.lineControllerStorage,
//            textContainerInset: textViewController.textContainerInset
//        )
//        return caretFactory.caret(at: location, allowMovingCaretToNextLineFragment: false)
//    }
//
//    func editMenuControllerShouldReplaceText(_ controller: EditMenuController) {
//        replaceTextInSelectedHighlightedRange()
//    }
//
//    func editMenuController(_ controller: EditMenuController, canReplaceTextIn highlightedRange: HighlightedRange) -> Bool {
//        editorDelegate?.textView(self, canReplaceTextIn: highlightedRange) ?? false
//    }
//
//    func editMenuController(_ controller: EditMenuController, highlightedRangeFor range: NSRange) -> HighlightedRange? {
//        highlightedRanges.first { $0.range == range }
//    }
//
//    func selectedRange(for controller: EditMenuController) -> NSRange? {
//        selectedRange
//    }
//}
#endif
