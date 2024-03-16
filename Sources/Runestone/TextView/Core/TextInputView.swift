// swiftlint:disable file_length
import Combine
import UIKit

protocol TextInputViewDelegate: AnyObject {
    func textInputViewWillBeginEditing(_ view: TextInputView)
    func textInputViewDidBeginEditing(_ view: TextInputView)
    func textInputViewDidEndEditing(_ view: TextInputView)
    func textInputViewDidCancelBeginEditing(_ view: TextInputView)
    func textInputViewDidChange(_ view: TextInputView)
    func textInputViewDidChangeSelection(_ view: TextInputView)
    func textInputView(_ view: TextInputView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
    func textInputViewDidInvalidateContentSize(_ view: TextInputView)
    func textInputView(_ view: TextInputView, didProposeContentOffsetAdjustment contentOffsetAdjustment: CGPoint)
    func textInputViewDidChangeGutterWidth(_ view: TextInputView)
    func textInputViewDidBeginFloatingCursor(_ view: TextInputView)
    func textInputViewDidEndFloatingCursor(_ view: TextInputView)
    func textInputViewDidUpdateMarkedRange(_ view: TextInputView)
    func textInputView(_ view: TextInputView, canReplaceTextIn highlightedRange: HighlightedRange) -> Bool
    func textInputView(_ view: TextInputView, replaceTextIn highlightedRange: HighlightedRange)
}

// swiftlint:disable:next type_body_length
final class TextInputView: UIView, UITextInput {
    // MARK: - UITextInput
    var selectedTextRange: UITextRange? {
        get {
            if let range = _selectedRange {
                return IndexedRange(range)
            } else {
                return nil
            }
        }
        set {
            // We should not use this setter. It's intended for UIKit to use. It'll invoke the setter in various scenarios, for example when navigating the text using the keyboard.
            // On the iOS 16 beta, UIKit may pass an NSRange with a negatives length (e.g. {4, -2}) when double tapping to select text. This will cause a crash when UIKit later attempts to use the selected range with NSString's -substringWithRange:. This can be tested with a string containing the following three lines:
            //    A
            //
            //    A
            // Placing the character on the second line, which is empty, and double tapping several times on the empty line to select text will cause the editor to crash. To work around this we take the non-negative value of the selected range. Last tested on August 30th, 2022.
            let newRange = (newValue as? IndexedRange)?.range.nonNegativeLength
            if newRange != _selectedRange {
                notifyDelegateAboutSelectionChangeInLayoutSubviews = true
                // The logic for determining whether or not to notify the input delegate is based on advice provided by Alexander Blach, developer of Textastic.
                var shouldNotifyInputDelegate = false
                if didCallPositionFromPositionInDirectionWithOffset {
                    shouldNotifyInputDelegate = true
                    didCallPositionFromPositionInDirectionWithOffset = false
                }
                // This is a consequence of our workaround that ensures multi-stage input, such as when entering Korean,
                // works correctly. The workaround causes bugs when selecting words using Shift + Option + Arrow Keys
                // followed by Shift + Arrow Keys if we do not treat it as a special case.
                // The consequence of not having this workaround is that Shift + Arrow Keys may adjust the wrong end of
                // the selected text when followed by navigating between word boundaries usign Shift + Option + Arrow Keys.
                if customTokenizer.didCallPositionFromPositionToWordBoundary && !didCallDeleteBackward {
                    shouldNotifyInputDelegate = true
                    customTokenizer.didCallPositionFromPositionToWordBoundary = false
                }
                didCallDeleteBackward = false
                notifyInputDelegateAboutSelectionChangeInLayoutSubviews = !shouldNotifyInputDelegate
                if shouldNotifyInputDelegate {
                    inputDelegate?.selectionWillChange(self)
                }
                _selectedRange = newRange
                if shouldNotifyInputDelegate {
                    inputDelegate?.selectionDidChange(self)
                }
            }
        }
    }
    private(set) var markedTextRange: UITextRange? {
        get {
            if let markedRange = markedRange {
                return IndexedRange(markedRange)
            } else {
                return nil
            }
        }
        set {
            markedRange = (newValue as? IndexedRange)?.range.nonNegativeLength
        }
    }
    var markedTextStyle: [NSAttributedString.Key: Any]?
    var beginningOfDocument: UITextPosition {
        IndexedPosition(index: 0)
    }
    var endOfDocument: UITextPosition {
        IndexedPosition(index: string.length)
    }
    weak var inputDelegate: UITextInputDelegate?
    var hasText: Bool {
        string.length > 0
    }
    var tokenizer: UITextInputTokenizer {
        customTokenizer
    }
    private lazy var customTokenizer = TextInputStringTokenizer(textInput: self,
                                                                stringView: stringView,
                                                                lineManager: lineManager,
                                                                lineControllerStorage: lineControllerStorage)
    var autocorrectionType: UITextAutocorrectionType = .default
    var autocapitalizationType: UITextAutocapitalizationType = .sentences
    var smartQuotesType: UITextSmartQuotesType = .default
    var smartDashesType: UITextSmartDashesType = .default
    var smartInsertDeleteType: UITextSmartInsertDeleteType = .default
    var spellCheckingType: UITextSpellCheckingType = .default
    var keyboardType: UIKeyboardType = .default
    var keyboardAppearance: UIKeyboardAppearance = .default
    var returnKeyType: UIReturnKeyType = .default
    @objc var insertionPointColor: UIColor = .label {
        didSet {
            if insertionPointColor != oldValue {
                updateCaretColor()
            }
        }
    }
    @objc var selectionBarColor: UIColor = .label {
        didSet {
            if selectionBarColor != oldValue {
                updateCaretColor()
            }
        }
    }
    @objc var selectionHighlightColor: UIColor = .label.withAlphaComponent(0.2) {
        didSet {
            if selectionHighlightColor != oldValue {
                updateCaretColor()
            }
        }
    }
    var isEditing = false {
        didSet {
            if isEditing != oldValue {
                layoutManager.isEditing = isEditing
            }
        }
    }
    override var undoManager: UndoManager? {
        timedUndoManager
    }

    // MARK: - Appearance
    var theme: Theme {
        didSet {
            applyThemeToChildren()
        }
    }
    var showLineNumbers = false {
        didSet {
            if showLineNumbers != oldValue {
                caretRectService.showLineNumbers = showLineNumbers
                gutterWidthService.showLineNumbers = showLineNumbers
                layoutManager.showLineNumbers = showLineNumbers
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var lineSelectionDisplayType: LineSelectionDisplayType {
        get {
            layoutManager.lineSelectionDisplayType
        }
        set {
            layoutManager.lineSelectionDisplayType = newValue
        }
    }
    var showTabs: Bool {
        get {
            invisibleCharacterConfiguration.showTabs
        }
        set {
            if newValue != invisibleCharacterConfiguration.showTabs {
                invisibleCharacterConfiguration.showTabs = newValue
                layoutManager.setNeedsDisplayOnLines()
            }
        }
    }
    var showSpaces: Bool {
        get {
            invisibleCharacterConfiguration.showSpaces
        }
        set {
            if newValue != invisibleCharacterConfiguration.showSpaces {
                invisibleCharacterConfiguration.showSpaces = newValue
                layoutManager.setNeedsDisplayOnLines()
            }
        }
    }
    var showNonBreakingSpaces: Bool {
        get {
            invisibleCharacterConfiguration.showNonBreakingSpaces
        }
        set {
            if newValue != invisibleCharacterConfiguration.showNonBreakingSpaces {
                invisibleCharacterConfiguration.showNonBreakingSpaces = newValue
                layoutManager.setNeedsDisplayOnLines()
            }
        }
    }
    var showLineBreaks: Bool {
        get {
            invisibleCharacterConfiguration.showLineBreaks
        }
        set {
            if newValue != invisibleCharacterConfiguration.showLineBreaks {
                invisibleCharacterConfiguration.showLineBreaks = newValue
                invalidateLines()
                layoutManager.setNeedsLayout()
                layoutManager.setNeedsDisplayOnLines()
                setNeedsLayout()
            }
        }
    }
    var showSoftLineBreaks: Bool {
        get {
            invisibleCharacterConfiguration.showSoftLineBreaks
        }
        set {
            if newValue != invisibleCharacterConfiguration.showSoftLineBreaks {
                invisibleCharacterConfiguration.showSoftLineBreaks = newValue
                invalidateLines()
                layoutManager.setNeedsLayout()
                layoutManager.setNeedsDisplayOnLines()
                setNeedsLayout()
            }
        }
    }
    var tabSymbol: String {
        get {
            invisibleCharacterConfiguration.tabSymbol
        }
        set {
            if newValue != invisibleCharacterConfiguration.tabSymbol {
                invisibleCharacterConfiguration.tabSymbol = newValue
                layoutManager.setNeedsDisplayOnLines()
            }
        }
    }
    var spaceSymbol: String {
        get {
            invisibleCharacterConfiguration.spaceSymbol
        }
        set {
            if newValue != invisibleCharacterConfiguration.spaceSymbol {
                invisibleCharacterConfiguration.spaceSymbol = newValue
                layoutManager.setNeedsDisplayOnLines()
            }
        }
    }
    var nonBreakingSpaceSymbol: String {
        get {
            invisibleCharacterConfiguration.nonBreakingSpaceSymbol
        }
        set {
            if newValue != invisibleCharacterConfiguration.nonBreakingSpaceSymbol {
                invisibleCharacterConfiguration.nonBreakingSpaceSymbol = newValue
                layoutManager.setNeedsDisplayOnLines()
            }
        }
    }
    var lineBreakSymbol: String {
        get {
            invisibleCharacterConfiguration.lineBreakSymbol
        }
        set {
            if newValue != invisibleCharacterConfiguration.lineBreakSymbol {
                invisibleCharacterConfiguration.lineBreakSymbol = newValue
                layoutManager.setNeedsDisplayOnLines()
            }
        }
    }
    var softLineBreakSymbol: String {
        get {
            invisibleCharacterConfiguration.softLineBreakSymbol
        }
        set {
            if newValue != invisibleCharacterConfiguration.softLineBreakSymbol {
                invisibleCharacterConfiguration.softLineBreakSymbol = newValue
                layoutManager.setNeedsDisplayOnLines()
            }
        }
    }
    var indentStrategy: IndentStrategy = .tab(length: 2) {
        didSet {
            if indentStrategy != oldValue {
                indentController.indentStrategy = indentStrategy
                layoutManager.setNeedsLayout()
                setNeedsLayout()
                layoutIfNeeded()
            }
        }
    }
    var gutterLeadingPadding: CGFloat = 3 {
        didSet {
            if gutterLeadingPadding != oldValue {
                gutterWidthService.gutterLeadingPadding = gutterLeadingPadding
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var gutterTrailingPadding: CGFloat = 3 {
        didSet {
            if gutterTrailingPadding != oldValue {
                gutterWidthService.gutterTrailingPadding = gutterTrailingPadding
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var gutterMinimumCharacterCount: Int = 1 {
        didSet {
            if gutterMinimumCharacterCount != oldValue {
                gutterWidthService.gutterMinimumCharacterCount = gutterMinimumCharacterCount
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var textContainerInset: UIEdgeInsets {
        get {
            layoutManager.textContainerInset
        }
        set {
            if newValue != layoutManager.textContainerInset {
                caretRectService.textContainerInset = newValue
                selectionRectService.textContainerInset = newValue
                contentSizeService.textContainerInset = newValue
                layoutManager.textContainerInset = newValue
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var isLineWrappingEnabled: Bool {
        get {
            layoutManager.isLineWrappingEnabled
        }
        set {
            if newValue != layoutManager.isLineWrappingEnabled {
                contentSizeService.isLineWrappingEnabled = newValue
                layoutManager.isLineWrappingEnabled = newValue
                invalidateLines()
                layoutManager.setNeedsLayout()
                layoutManager.layoutIfNeeded()
            }
        }
    }
    var lineBreakMode: LineBreakMode = .byWordWrapping {
        didSet {
            if lineBreakMode != oldValue {
                invalidateLines()
                contentSizeService.invalidateContentSize()
                layoutManager.setNeedsLayout()
                layoutManager.layoutIfNeeded()
            }
        }
    }
    var gutterWidth: CGFloat {
        gutterWidthService.gutterWidth
    }
    var lineHeightMultiplier: CGFloat = 1 {
        didSet {
            if lineHeightMultiplier != oldValue {
                selectionRectService.lineHeightMultiplier = lineHeightMultiplier
                layoutManager.lineHeightMultiplier = lineHeightMultiplier
                invalidateLines()
                lineManager.estimatedLineHeight = estimatedLineHeight
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var kern: CGFloat = 0 {
        didSet {
            if kern != oldValue {
                invalidateLines()
                pageGuideController.kern = kern
                contentSizeService.invalidateContentSize()
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var characterPairs: [CharacterPair] = [] {
        didSet {
            maximumLeadingCharacterPairComponentLength = characterPairs.map(\.leading.utf16.count).max() ?? 0
        }
    }
    var characterPairTrailingComponentDeletionMode: CharacterPairTrailingComponentDeletionMode = .disabled
    var showPageGuide = false {
        didSet {
            if showPageGuide != oldValue {
                if showPageGuide {
                    addSubview(pageGuideController.guideView)
                    sendSubviewToBack(pageGuideController.guideView)
                    setNeedsLayout()
                } else {
                    pageGuideController.guideView.removeFromSuperview()
                    setNeedsLayout()
                }
            }
        }
    }
    var pageGuideColumn: Int {
        get {
            pageGuideController.column
        }
        set {
            if newValue != pageGuideController.column {
                pageGuideController.column = newValue
                setNeedsLayout()
            }
        }
    }
    private var estimatedLineHeight: CGFloat {
        theme.font.totalLineHeight * lineHeightMultiplier
    }
    var highlightedRanges: [HighlightedRange] {
        get {
            highlightService.highlightedRanges
        }
        set {
            if newValue != highlightService.highlightedRanges {
                highlightService.highlightedRanges = newValue
                layoutManager.setNeedsLayout()
                layoutManager.layoutIfNeeded()
            }
        }
    }

    // MARK: - Contents
    weak var delegate: TextInputViewDelegate?
    var string: NSString {
        get {
            stringView.string
        }
        set {
            if newValue != stringView.string {
                stringView.string = newValue
                languageMode.parse(newValue)
                lineManager.rebuild()
                if let oldSelectedRange = selectedRange {
                    inputDelegate?.selectionWillChange(self)
                    selectedRange = safeSelectionRange(from: oldSelectedRange)
                    inputDelegate?.selectionDidChange(self)
                }
                contentSizeService.invalidateContentSize()
                gutterWidthService.invalidateLineNumberWidth()
                invalidateLines()
                layoutManager.setNeedsLayout()
                layoutManager.layoutIfNeeded()
                if !preserveUndoStackWhenSettingString {
                    undoManager?.removeAllActions()
                }
            }
        }
    }
    var viewport: CGRect {
        get {
            layoutManager.viewport
        }
        set {
            if newValue != layoutManager.viewport {
                layoutManager.viewport = newValue
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var scrollViewWidth: CGFloat = 0 {
        didSet {
            if scrollViewWidth != oldValue {
                contentSizeService.scrollViewWidth = scrollViewWidth
                layoutManager.scrollViewWidth = scrollViewWidth
                if isLineWrappingEnabled {
                    invalidateLines()
                }
            }
        }
    }
    var contentSize: CGSize {
        contentSizeService.contentSize
    }
    var selectedRange: NSRange? {
        get {
            _selectedRange
        }
        set {
            if newValue != _selectedRange {
                _selectedRange = newValue
                delegate?.textInputViewDidChangeSelection(self)
            }
        }
    }
    private var _selectedRange: NSRange? {
        didSet {
            if _selectedRange != oldValue {
                layoutManager.selectedRange = _selectedRange
                layoutManager.setNeedsLayoutLineSelection()
                setNeedsLayout()
            }
        }
    }
    override var canBecomeFirstResponder: Bool {
        true
    }
    weak var gutterParentView: UIView? {
        get {
            layoutManager.gutterParentView
        }
        set {
            layoutManager.gutterParentView = newValue
        }
    }
    var scrollViewSafeAreaInsets: UIEdgeInsets = .zero {
        didSet {
            if scrollViewSafeAreaInsets != oldValue {
                layoutManager.safeAreaInsets = scrollViewSafeAreaInsets
            }
        }
    }
    var gutterContainerView: UIView {
        layoutManager.gutterContainerView
    }
    private(set) var stringView = StringView() {
        didSet {
            if stringView !== oldValue {
                caretRectService.stringView = stringView
                lineManager.stringView = stringView
                lineControllerFactory.stringView = stringView
                lineControllerStorage.stringView = stringView
                layoutManager.stringView = stringView
                indentController.stringView = stringView
                lineMovementController.stringView = stringView
                customTokenizer.stringView = stringView
            }
        }
    }
    private(set) var lineManager: LineManager {
        didSet {
            if lineManager !== oldValue {
                indentController.lineManager = lineManager
                lineMovementController.lineManager = lineManager
                gutterWidthService.lineManager = lineManager
                contentSizeService.lineManager = lineManager
                caretRectService.lineManager = lineManager
                selectionRectService.lineManager = lineManager
                highlightService.lineManager = lineManager
                customTokenizer.lineManager = lineManager
            }
        }
    }
    var viewHierarchyContainsCaret: Bool {
        textSelectionView?.subviews.count == 1
    }
    var lineEndings: LineEnding = .lf
    private(set) var isRestoringPreviouslyDeletedText = false

    // MARK: - Private
    private var languageMode: InternalLanguageMode = PlainTextInternalLanguageMode() {
        didSet {
            if languageMode !== oldValue {
                indentController.languageMode = languageMode
                if let treeSitterLanguageMode = languageMode as? TreeSitterInternalLanguageMode {
                    treeSitterLanguageMode.delegate = self
                }
            }
        }
    }
    private let lineControllerFactory: LineControllerFactory
    private let lineControllerStorage: LineControllerStorage
    private let layoutManager: LayoutManager
    private let timedUndoManager = TimedUndoManager()
    private let indentController: IndentController
    private let lineMovementController: LineMovementController
    private let pageGuideController = PageGuideController()
    private let gutterWidthService: GutterWidthService
    private let contentSizeService: ContentSizeService
    private let caretRectService: CaretRectService
    private let selectionRectService: SelectionRectService
    private let highlightService: HighlightService
    private let invisibleCharacterConfiguration = InvisibleCharacterConfiguration()
    private var markedRange: NSRange? {
        get {
            layoutManager.markedRange
        }
        set {
            layoutManager.markedRange = newValue
        }
    }
    private var floatingCaretView: FloatingCaretView?
    private var insertionPointColorBeforeFloatingBegan: UIColor = .label
    private var maximumLeadingCharacterPairComponentLength = 0
    private var textSelectionView: UIView? {
        if let klass = NSClassFromString("UITextSelectionView") {
            return subviews.first { $0.isKind(of: klass) }
        } else {
            return nil
        }
    }
    private var hasPendingFullLayout = false
    private let editMenuController = EditMenuController()
    private var notifyInputDelegateAboutSelectionChangeInLayoutSubviews = false
    private var notifyDelegateAboutSelectionChangeInLayoutSubviews = false
    private var didCallPositionFromPositionInDirectionWithOffset = false
    private var didCallDeleteBackward = false
    private var hasDeletedTextWithPendingLayoutSubviews = false
    private var preserveUndoStackWhenSettingString = false
    private var cancellables: [AnyCancellable] = []

    // MARK: - Lifecycle
    init(theme: Theme) {
        self.theme = theme
        lineManager = LineManager(stringView: stringView)
        highlightService = HighlightService(lineManager: lineManager)
        lineControllerFactory = LineControllerFactory(stringView: stringView,
                                                      highlightService: highlightService,
                                                      invisibleCharacterConfiguration: invisibleCharacterConfiguration)
        lineControllerStorage = LineControllerStorage(stringView: stringView, lineControllerFactory: lineControllerFactory)
        gutterWidthService = GutterWidthService(lineManager: lineManager)
        contentSizeService = ContentSizeService(lineManager: lineManager,
                                                lineControllerStorage: lineControllerStorage,
                                                gutterWidthService: gutterWidthService,
                                                invisibleCharacterConfiguration: invisibleCharacterConfiguration)
        caretRectService = CaretRectService(stringView: stringView,
                                            lineManager: lineManager,
                                            lineControllerStorage: lineControllerStorage,
                                            gutterWidthService: gutterWidthService)
        selectionRectService = SelectionRectService(lineManager: lineManager,
                                                    contentSizeService: contentSizeService,
                                                    gutterWidthService: gutterWidthService,
                                                    caretRectService: caretRectService)
        layoutManager = LayoutManager(lineManager: lineManager,
                                      languageMode: languageMode,
                                      stringView: stringView,
                                      lineControllerStorage: lineControllerStorage,
                                      contentSizeService: contentSizeService,
                                      gutterWidthService: gutterWidthService,
                                      caretRectService: caretRectService,
                                      selectionRectService: selectionRectService,
                                      highlightService: highlightService,
                                      invisibleCharacterConfiguration: invisibleCharacterConfiguration)
        indentController = IndentController(stringView: stringView,
                                            lineManager: lineManager,
                                            languageMode: languageMode,
                                            indentStrategy: indentStrategy,
                                            indentFont: theme.font)
        lineMovementController = LineMovementController(lineManager: lineManager,
                                                        stringView: stringView,
                                                        lineControllerStorage: lineControllerStorage)
        super.init(frame: .zero)
        applyThemeToChildren()
        indentController.delegate = self
        lineControllerStorage.delegate = self
        gutterWidthService.gutterLeadingPadding = gutterLeadingPadding
        gutterWidthService.gutterTrailingPadding = gutterTrailingPadding
        layoutManager.delegate = self
        layoutManager.textInputView = self
        editMenuController.delegate = self
        editMenuController.setupEditMenu(in: self)
        setupContentSizeObserver()
        setupGutterWidthObserver()
    }

    override func becomeFirstResponder() -> Bool {
        if canBecomeFirstResponder {
            delegate?.textInputViewWillBeginEditing(self)
        }
        let didBecomeFirstResponder = super.becomeFirstResponder()
        if didBecomeFirstResponder {
            delegate?.textInputViewDidBeginEditing(self)
        } else {
            // This is called in the case where:
            // 1. The view is the first responder.
            // 2. A view is presented modally on top of the editor.
            // 3. The modally presented view is dismissed.
            // 4. The responder chain attempts to make the text view first responder again but super.becomeFirstResponder() returns false.
            delegate?.textInputViewDidCancelBeginEditing(self)
        }
        return didBecomeFirstResponder
    }

    override func resignFirstResponder() -> Bool {
        let didResignFirstResponder = super.resignFirstResponder()
        if didResignFirstResponder {
            delegate?.textInputViewDidEndEditing(self)
        }
        return didResignFirstResponder
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        hasDeletedTextWithPendingLayoutSubviews = false
        layoutManager.layoutIfNeeded()
        layoutManager.layoutLineSelectionIfNeeded()
        layoutPageGuideIfNeeded()
        // We notify the input delegate about selection changes in layoutSubviews so we have a chance of disabling notifying the input delegate during an editing operation.
        // We will sometimes disable notifying the input delegate when the user enters Korean text.
        // This workaround is inspired by a dialog with Alexander Blach (@lextar), developer of Textastic.
        if notifyInputDelegateAboutSelectionChangeInLayoutSubviews {
            inputDelegate?.selectionWillChange(self)
            inputDelegate?.selectionDidChange(self)
        }
        if notifyDelegateAboutSelectionChangeInLayoutSubviews {
            notifyDelegateAboutSelectionChangeInLayoutSubviews = false
            delegate?.textInputViewDidChangeSelection(self)
        }
    }

    override func copy(_ sender: Any?) {
        if let selectedTextRange = selectedTextRange, let text = text(in: selectedTextRange) {
            UIPasteboard.general.string = text
        }
    }

    override func paste(_ sender: Any?) {
        if let selectedTextRange = selectedTextRange, let string = UIPasteboard.general.string {
            inputDelegate?.selectionWillChange(self)
            let preparedText = prepareTextForInsertion(string)
            replace(selectedTextRange, withText: preparedText)
            inputDelegate?.selectionDidChange(self)
        }
    }

    override func cut(_ sender: Any?) {
        if let selectedTextRange = selectedTextRange, let text = text(in: selectedTextRange) {
            UIPasteboard.general.string = text
            replace(selectedTextRange, withText: "")
        }
    }

    override func selectAll(_ sender: Any?) {
        notifyInputDelegateAboutSelectionChangeInLayoutSubviews = true
        selectedRange = NSRange(location: 0, length: string.length)
    }

    /// When autocorrection is enabled and the user tap on a misspelled word, UITextInteraction will present
    /// a UIMenuController with suggestions for the correct spelling of the word. Selecting a suggestion will
    /// cause UITextInteraction to call the non-existing -replace(_:) function and pass an instance of the private
    /// UITextReplacement type as parameter. We can't make autocorrection work properly without using private API.
    @objc func replace(_ obj: NSObject) {
        if let replacementText = obj.value(forKey: "_repl" + "Ttnemeca".reversed() + "ext") as? String {
            if let indexedRange = obj.value(forKey: "_r" + "gna".reversed() + "e") as? IndexedRange {
                replace(indexedRange, withText: replacementText)
            }
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
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
            if let selectedRange = selectedRange, let highlightedRange = highlightedRange(for: selectedRange) {
                return delegate?.textInputView(self, canReplaceTextIn: highlightedRange) ?? false
            } else {
                return false
            }
        } else {
            return super.canPerformAction(action, withSender: sender)
        }
    }

    func linePosition(at location: Int) -> LinePosition? {
        lineManager.linePosition(at: location)
    }

    func setState(_ state: TextViewState, addUndoAction: Bool = false) {
        let oldText = stringView.string
        let newText = state.stringView.string
        stringView = state.stringView
        theme = state.theme
        languageMode = state.languageMode
        lineControllerStorage.removeAllLineControllers()
        lineManager = state.lineManager
        lineManager.estimatedLineHeight = estimatedLineHeight
        layoutManager.languageMode = state.languageMode
        layoutManager.lineManager = state.lineManager
        contentSizeService.invalidateContentSize()
        gutterWidthService.invalidateLineNumberWidth()
        if addUndoAction {
            if newText != oldText {
                let newRange = NSRange(location: 0, length: newText.length)
                timedUndoManager.endUndoGrouping()
                timedUndoManager.beginUndoGrouping()
                addUndoOperation(replacing: newRange, withText: oldText as String)
                timedUndoManager.endUndoGrouping()
            }
        } else {
            timedUndoManager.removeAllActions()
        }
        if let oldSelectedRange = selectedRange {
            inputDelegate?.selectionWillChange(self)
            selectedRange = safeSelectionRange(from: oldSelectedRange)
            inputDelegate?.selectionDidChange(self)
        }
        if window != nil {
            performFullLayout()
        } else {
            hasPendingFullLayout = true
        }
    }

    func clearSelection() {
        selectedRange = nil
    }

    func moveCaret(to point: CGPoint) {
        if let index = layoutManager.closestIndex(to: point) {
            selectedRange = NSRange(location: index, length: 0)
        }
    }

    func setLanguageMode(_ languageMode: LanguageMode, completion: ((Bool) -> Void)? = nil) {
        let internalLanguageMode = InternalLanguageModeFactory.internalLanguageMode(
            from: languageMode,
            stringView: stringView,
            lineManager: lineManager)
        self.languageMode = internalLanguageMode
        layoutManager.languageMode = internalLanguageMode
        internalLanguageMode.parse(string) { [weak self] finished in
            if let self = self, finished {
                self.invalidateLines()
                self.layoutManager.setNeedsLayout()
                self.layoutManager.layoutIfNeeded()
            }
            completion?(finished)
        }
    }

    func syntaxNode(at location: Int) -> SyntaxNode? {
        if let linePosition = lineManager.linePosition(at: location) {
            return languageMode.syntaxNode(at: linePosition)
        } else {
            return nil
        }
    }

    func isIndentation(at location: Int) -> Bool {
        guard let line = lineManager.line(containingCharacterAt: location) else {
            return false
        }
        let localLocation = location - line.location
        guard localLocation >= 0 else {
            return false
        }
        let indentLevel = languageMode.currentIndentLevel(of: line, using: indentStrategy)
        let indentString = indentStrategy.string(indentLevel: indentLevel)
        return localLocation <= indentString.utf16.count
    }

    func detectIndentStrategy() -> DetectedIndentStrategy {
        languageMode.detectIndentStrategy()
    }

    func textPreview(containing range: NSRange) -> TextPreview? {
        layoutManager.textPreview(containing: range)
    }

    func layoutLines(toLocation location: Int) {
        layoutManager.layoutLines(toLocation: location)
    }

    func redisplayVisibleLines() {
        layoutManager.redisplayVisibleLines()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if hasPendingFullLayout && window != nil {
            hasPendingFullLayout = false
            performFullLayout()
        }
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // We end our current undo group when the user touches the view.
        let result = super.hitTest(point, with: event)
        if result === self {
            timedUndoManager.endUndoGrouping()
        }
        return result
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            invalidateLines()
            layoutManager.setNeedsLayout()
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
        if let keyCode = presses.first?.key?.keyCode, presses.count == 1 {
            if markedRange != nil {
                handleKeyPressDuringMultistageTextInput(keyCode: keyCode)
            }
        }
    }
}

// MARK: - Theming
private extension TextInputView {
    private func applyThemeToChildren() {
        gutterWidthService.font = theme.lineNumberFont
        lineManager.estimatedLineHeight = estimatedLineHeight
        indentController.indentFont = theme.font
        pageGuideController.font = theme.font
        pageGuideController.guideView.hairlineWidth = theme.pageGuideHairlineWidth
        pageGuideController.guideView.hairlineColor = theme.pageGuideHairlineColor
        pageGuideController.guideView.backgroundColor = theme.pageGuideBackgroundColor
        layoutManager.theme = theme
    }
}

// MARK: - Navigation
private extension TextInputView {
    private func handleKeyPressDuringMultistageTextInput(keyCode: UIKeyboardHIDUsage) {
        // When editing multistage text input (that is, we have a marked text) we let the user unmark the text
        // by pressing the arrow keys or Escape. This isn't common in iOS apps but it's the default behavior
        // on macOS and I think that works quite well for plain text editors on iOS too.
        guard let markedRange = markedRange, let markedText = stringView.substring(in: markedRange) else {
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
            navigate(in: .up, offset: 1)
            unmarkText()
        case .keyboardRightArrow:
            navigate(in: .right, offset: 1)
            unmarkText()
        case .keyboardDownArrow:
            navigate(in: .down, offset: 1)
            unmarkText()
        case .keyboardLeftArrow:
            navigate(in: .left, offset: 1)
            unmarkText()
        case .keyboardEscape:
            unmarkText()
        default:
            break
        }
    }

    private func navigate(in direction: UITextLayoutDirection, offset: Int) {
        if let selectedRange = selectedRange {
            if let location = lineMovementController.location(from: selectedRange.location, in: direction, offset: offset) {
                self.selectedRange = NSRange(location: location, length: 0)
            }
        }
    }
}

// MARK: - Layout
private extension TextInputView {
    private func layoutPageGuideIfNeeded() {
        if showPageGuide {
            // The width extension is used to make the page guide look "attached" to the right hand side, even when the scroll view bouncing on the right side.
            let maxContentOffsetX = contentSizeService.contentWidth - viewport.width
            let widthExtension = max(ceil(viewport.minX - maxContentOffsetX), 0)
            let xPosition = gutterWidthService.gutterWidth + textContainerInset.left + pageGuideController.columnOffset
            let width = max(bounds.width - xPosition + widthExtension, 0)
            let orrigin = CGPoint(x: xPosition, y: viewport.minY)
            let pageGuideSize = CGSize(width: width, height: viewport.height)
            pageGuideController.guideView.frame = CGRect(origin: orrigin, size: pageGuideSize)
        }
    }

    private func performFullLayout() {
        invalidateLines()
        layoutManager.setNeedsLayout()
        layoutManager.layoutIfNeeded()
    }

    private func invalidateLines() {
        for lineController in lineControllerStorage {
            lineController.lineFragmentHeightMultiplier = lineHeightMultiplier
            lineController.tabWidth = indentController.tabWidth
            lineController.kern = kern
            lineController.lineBreakMode = lineBreakMode
            lineController.invalidateSyntaxHighlighting()
        }
    }

    private func setupContentSizeObserver() {
        contentSizeService.$isContentSizeInvalid.filter { $0 }.sink { [weak self] _ in
            if let self = self {
                self.delegate?.textInputViewDidInvalidateContentSize(self)
            }
        }.store(in: &cancellables)
    }

    private func setupGutterWidthObserver() {
        gutterWidthService.didUpdateGutterWidth.sink { [weak self] in
            if let self = self {
                // Typeset lines again when the line number width changes since changing line number width may increase or reduce the number of line fragments in a line.
                self.setNeedsLayout()
                self.invalidateLines()
                self.layoutManager.setNeedsLayout()
                self.delegate?.textInputViewDidChangeGutterWidth(self)
            }
        }.store(in: &cancellables)
    }
}

// MARK: - Floating Caret
extension TextInputView {
    func beginFloatingCursor(at point: CGPoint) {
        if floatingCaretView == nil, let position = closestPosition(to: point) {
            insertionPointColorBeforeFloatingBegan = insertionPointColor
            insertionPointColor = insertionPointColorBeforeFloatingBegan.withAlphaComponent(0.5)
            updateCaretColor()
            let caretRect = self.caretRect(for: position)
            let caretOrigin = CGPoint(x: point.x - caretRect.width / 2, y: point.y - caretRect.height / 2)
            let floatingCaretView = FloatingCaretView()
            floatingCaretView.backgroundColor = insertionPointColorBeforeFloatingBegan
            floatingCaretView.frame = CGRect(origin: caretOrigin, size: caretRect.size)
            addSubview(floatingCaretView)
            self.floatingCaretView = floatingCaretView
            delegate?.textInputViewDidBeginFloatingCursor(self)
        }
    }

    func updateFloatingCursor(at point: CGPoint) {
        if let floatingCaretView = floatingCaretView {
            let caretSize = floatingCaretView.frame.size
            let caretOrigin = CGPoint(x: point.x - caretSize.width / 2, y: point.y - caretSize.height / 2)
            floatingCaretView.frame = CGRect(origin: caretOrigin, size: caretSize)
        }
    }

    func endFloatingCursor() {
        insertionPointColor = insertionPointColorBeforeFloatingBegan
        updateCaretColor()
        floatingCaretView?.removeFromSuperview()
        floatingCaretView = nil
        delegate?.textInputViewDidEndFloatingCursor(self)
    }

    private func updateCaretColor() {
        // Removing the UITextSelectionView and re-adding it forces it to query the insertion point color.
        if let textSelectionView = textSelectionView {
            textSelectionView.removeFromSuperview()
            addSubview(textSelectionView)
        }
    }
}

// MARK: - Rects
extension TextInputView {
    func caretRect(for position: UITextPosition) -> CGRect {
        guard let indexedPosition = position as? IndexedPosition else {
            fatalError("Expected position to be of type \(IndexedPosition.self)")
        }
        return caretRectService.caretRect(at: indexedPosition.index, allowMovingCaretToNextLineFragment: true)
    }

    func caretRect(at location: Int) -> CGRect {
        caretRectService.caretRect(at: location, allowMovingCaretToNextLineFragment: true)
    }

    func firstRect(for range: UITextRange) -> CGRect {
        guard let indexedRange = range as? IndexedRange else {
            fatalError("Expected range to be of type \(IndexedRange.self)")
        }
        return layoutManager.firstRect(for: indexedRange.range)
    }
}

// MARK: - Editing
extension TextInputView {
    func insertText(_ text: String) {
        let preparedText = prepareTextForInsertion(text)
        isRestoringPreviouslyDeletedText = hasDeletedTextWithPendingLayoutSubviews
        hasDeletedTextWithPendingLayoutSubviews = false
        defer {
            isRestoringPreviouslyDeletedText = false
        }
        // If there is no marked range or selected range then we fallback to appending text to the end of our string.
        let selectedRange = markedRange ?? selectedRange ?? NSRange(location: stringView.string.length, length: 0)
        guard shouldChangeText(in: selectedRange, replacementText: preparedText) else {
            isRestoringPreviouslyDeletedText = false
            return
        }
        // If we're inserting text then we can't have a marked range. However, UITextInput doesn't always clear the marked range
        // before calling -insertText(_:), so we do it manually. This issue can be tested by entering a backtick (`) in an empty
        // document, then pressing any arrow key (up, right, down or left) followed by the return key.
        // The backtick will remain marked unless we manually clear the marked range.
        markedRange = nil
        if LineEnding(symbol: text) != nil {
            indentController.insertLineBreak(in: selectedRange, using: lineEndings)
            layoutIfNeeded()
            delegate?.textInputViewDidChangeSelection(self)
        } else {
            replaceText(in: selectedRange, with: preparedText)
            layoutIfNeeded()
            delegate?.textInputViewDidChangeSelection(self)
        }
    }

    func deleteBackward() {
        didCallDeleteBackward = true
        guard let selectedRange = markedRange ?? selectedRange, selectedRange.length > 0 else {
            return
        }
        let deleteRange = rangeForDeletingText(in: selectedRange)
        // If we're deleting everything in the marked range then we clear the marked range. UITextInput doesn't do that for us.
        // Can be tested by entering a backtick (`) in an empty document and deleting it.
        if deleteRange == markedRange {
            markedRange = nil
        }
        guard shouldChangeText(in: deleteRange, replacementText: "") else {
            return
        }
        // Set a flag indicating that we have deleted text. This is reset in -layoutSubviews() but if this has not been reset before insertText() is called, then UIKit deleted characters prior to inserting combined characters. This happens when UIKit turns Korean characters into a single character. E.g. when typing ㅇ followed by ㅓ UIKit will perform the following operations:
        // 1. Delete ㅇ.
        // 2. Delete the character before ㅇ. I'm unsure why this is needed.
        // 3. Insert the character that was previously before ㅇ.
        // 4. Insert the ㅇ and ㅓ but combined into the single character delete ㅇ and then insert 어.
        // We can detect this case in insertText() by checking if this variable is true.
        hasDeletedTextWithPendingLayoutSubviews = true
        // Disable notifying delegate in layout subviews to prevent sending the selected range with length > 0 when deleting text. This aligns with the behavior of UITextView and was introduced to resolve issue #158: https://github.com/simonbs/Runestone/issues/158
        notifyDelegateAboutSelectionChangeInLayoutSubviews = false
        // Disable notifying input delegate in layout subviews to prevent issues when entering Korean text. This workaround is inspired by a dialog with Alexander Black (@lextar), developer of Textastic.
        notifyInputDelegateAboutSelectionChangeInLayoutSubviews = false
        // Just before calling deleteBackward(), UIKit will set the selected range to a range of length 1, if the selected range has a length of 0.
        // In that case we want to undo to a selected range of length 0, so we construct our range here and pass it all the way to the undo operation.
        let selectedRangeAfterUndo: NSRange
        if deleteRange.length == 1 {
            selectedRangeAfterUndo = NSRange(location: selectedRange.upperBound, length: 0)
        } else {
            selectedRangeAfterUndo = selectedRange
        }
        let isDeletingMultipleCharacters = selectedRange.length > 1
        if isDeletingMultipleCharacters {
            timedUndoManager.endUndoGrouping()
            timedUndoManager.beginUndoGrouping()
        }
        replaceText(in: deleteRange, with: "", selectedRangeAfterUndo: selectedRangeAfterUndo)
        // Sending selection changed without calling the input delegate directly. This ensures that both inputting Korean letters and deleting entire words with Option+Backspace works properly.
        sendSelectionChangedToTextSelectionView()
        if isDeletingMultipleCharacters {
            timedUndoManager.endUndoGrouping()
        }
        delegate?.textInputViewDidChangeSelection(self)
    }

    func replace(_ range: UITextRange, withText text: String) {
        let preparedText = prepareTextForInsertion(text)
        if let indexedRange = range as? IndexedRange, shouldChangeText(in: indexedRange.range.nonNegativeLength, replacementText: preparedText) {
            replaceText(in: indexedRange.range.nonNegativeLength, with: preparedText)
            delegate?.textInputViewDidChangeSelection(self)
        }
    }

    func replaceText(in batchReplaceSet: BatchReplaceSet) {
        guard !batchReplaceSet.replacements.isEmpty else {
            return
        }
        var oldLinePosition: LinePosition?
        if let oldSelectedRange = selectedRange {
            oldLinePosition = lineManager.linePosition(at: oldSelectedRange.location)
        }
        let textEditHelper = TextEditHelper(stringView: stringView, lineManager: lineManager, lineEndings: lineEndings)
        let newString = textEditHelper.string(byApplying: batchReplaceSet)
        setStringWithUndoAction(newString)
        if let oldLinePosition = oldLinePosition {
            // By restoring the selected range using the old line position we can better preserve the old selected language.
            moveCaret(to: oldLinePosition)
        }
    }

    func text(in range: UITextRange) -> String? {
        if let indexedRange = range as? IndexedRange {
            return text(in: indexedRange.range.nonNegativeLength)
        } else {
            return nil
        }
    }

    func text(in range: NSRange) -> String? {
        stringView.substring(in: range)
    }

    private func setStringWithUndoAction(_ newString: NSString) {
        guard newString != string else {
            return
        }
        guard let oldString = stringView.string.copy() as? NSString else {
            return
        }
        timedUndoManager.endUndoGrouping()
        let oldSelectedRange = selectedRange
        preserveUndoStackWhenSettingString = true
        string = newString
        preserveUndoStackWhenSettingString = false
        timedUndoManager.beginUndoGrouping()
        timedUndoManager.setActionName(L10n.Undo.ActionName.replaceAll)
        timedUndoManager.registerUndo(withTarget: self) { textInputView in
            textInputView.setStringWithUndoAction(oldString)
        }
        timedUndoManager.endUndoGrouping()
        delegate?.textInputViewDidChange(self)
        if let oldSelectedRange = oldSelectedRange {
            selectedRange = safeSelectionRange(from: oldSelectedRange)
        }
    }

    private func rangeForDeletingText(in range: NSRange) -> NSRange {
        var resultingRange = range
        if range.length == 1, let indentRange = indentController.indentRangeInFrontOfLocation(range.upperBound) {
            resultingRange = indentRange
        } else {
            resultingRange = string.customRangeOfComposedCharacterSequences(for: range)
        }
        // If deleting the leading component of a character pair we may also expand the range to delete the trailing component.
        if characterPairTrailingComponentDeletionMode == .immediatelyFollowingLeadingComponent
            && maximumLeadingCharacterPairComponentLength > 0
            && resultingRange.length <= maximumLeadingCharacterPairComponentLength {
            let stringToDelete = stringView.substring(in: resultingRange)
            if let characterPair = characterPairs.first(where: { $0.leading == stringToDelete }) {
                let trailingComponentLength = characterPair.trailing.utf16.count
                let trailingComponentRange = NSRange(location: resultingRange.upperBound, length: trailingComponentLength)
                if stringView.substring(in: trailingComponentRange) == characterPair.trailing {
                    let deleteRange = trailingComponentRange.upperBound - resultingRange.lowerBound
                    resultingRange = NSRange(location: resultingRange.lowerBound, length: deleteRange)
                }
            }
        }
        return resultingRange
    }

    private func replaceText(in range: NSRange,
                             with newString: String,
                             selectedRangeAfterUndo: NSRange? = nil,
                             undoActionName: String = L10n.Undo.ActionName.typing) {
        let nsNewString = newString as NSString
        let currentText = text(in: range) ?? ""
        let newRange = NSRange(location: range.location, length: nsNewString.length)
        addUndoOperation(replacing: newRange, withText: currentText, selectedRangeAfterUndo: selectedRangeAfterUndo, actionName: undoActionName)
        _selectedRange = NSRange(location: newRange.upperBound, length: 0)
        let textEditHelper = TextEditHelper(stringView: stringView, lineManager: lineManager, lineEndings: lineEndings)
        let textEditResult = textEditHelper.replaceText(in: range, with: newString)
        let textChange = textEditResult.textChange
        let lineChangeSet = textEditResult.lineChangeSet
        let languageModeLineChangeSet = languageMode.textDidChange(textChange)
        lineChangeSet.union(with: languageModeLineChangeSet)
        applyLineChangesToLayoutManager(lineChangeSet)
        let updatedTextEditResult = TextEditResult(textChange: textChange, lineChangeSet: lineChangeSet)
        delegate?.textInputViewDidChange(self)
        if updatedTextEditResult.didAddOrRemoveLines {
            delegate?.textInputViewDidInvalidateContentSize(self)
        }
    }

    private func applyLineChangesToLayoutManager(_ lineChangeSet: LineChangeSet) {
        let didAddOrRemoveLines = !lineChangeSet.insertedLines.isEmpty || !lineChangeSet.removedLines.isEmpty
        if didAddOrRemoveLines {
            contentSizeService.invalidateContentSize()
            for removedLine in lineChangeSet.removedLines {
                lineControllerStorage.removeLineController(withID: removedLine.id)
                contentSizeService.removeLine(withID: removedLine.id)
            }
        }
        let editedLineIDs = Set(lineChangeSet.editedLines.map(\.id))
        layoutManager.redisplayLines(withIDs: editedLineIDs)
        if didAddOrRemoveLines {
            gutterWidthService.invalidateLineNumberWidth()
        }
        layoutManager.setNeedsLayout()
        layoutManager.layoutIfNeeded()
    }

    private func shouldChangeText(in range: NSRange, replacementText text: String) -> Bool {
        delegate?.textInputView(self, shouldChangeTextIn: range, replacementText: text) ?? true
    }

    private func addUndoOperation(replacing range: NSRange,
                                  withText text: String,
                                  selectedRangeAfterUndo: NSRange? = nil,
                                  actionName: String = L10n.Undo.ActionName.typing) {
        let oldSelectedRange = selectedRangeAfterUndo ?? selectedRange
        timedUndoManager.beginUndoGrouping()
        timedUndoManager.setActionName(actionName)
        timedUndoManager.registerUndo(withTarget: self) { textInputView in
            textInputView.inputDelegate?.selectionWillChange(textInputView)
            textInputView.replaceText(in: range, with: text)
            textInputView.selectedRange = oldSelectedRange
            textInputView.inputDelegate?.selectionDidChange(textInputView)
        }
    }

    private func prepareTextForInsertion(_ text: String) -> String {
        // Ensure all line endings match our preferred line endings.
        var preparedText = text
        let lineEndingsToReplace: [LineEnding] = [.crlf, .cr, .lf].filter { $0 != lineEndings }
        for lineEnding in lineEndingsToReplace {
            preparedText = preparedText.replacingOccurrences(of: lineEnding.symbol, with: lineEndings.symbol)
        }
        return preparedText
    }
}

// MARK: - Selection
extension TextInputView {
    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        if let indexedRange = range as? IndexedRange {
            return selectionRectService.selectionRects(in: indexedRange.range.nonNegativeLength)
        } else {
            return []
        }
    }

    private func safeSelectionRange(from range: NSRange) -> NSRange {
        let stringLength = stringView.string.length
        let cappedLocation = min(max(range.location, 0), stringLength)
        let cappedLength = min(max(range.length, 0), stringLength - cappedLocation)
        return NSRange(location: cappedLocation, length: cappedLength)
    }

    private func moveCaret(to linePosition: LinePosition) {
        if linePosition.row < lineManager.lineCount {
            let line = lineManager.line(atRow: linePosition.row)
            let location = line.location + min(linePosition.column, line.data.length)
            selectedRange = NSRange(location: location, length: 0)
        } else {
            selectedRange = nil
        }
    }

    private func sendSelectionChangedToTextSelectionView() {
        // The only way I've found to get the selection change to be reflected properly while still supporting Korean, Chinese, and deleting words with Option+Backspace is to call a private API in some cases. However, as pointed out by Alexander Blach in the following PR, there is another workaround to the issue.
        // When passing nil to the input delete, the text selection is update but the text input ignores it.
        // Even the Swift Playgrounds app does not get this right for all languages in all cases, so there seems to be some workarounds needed to due bugs in internal classes in UIKit that communicate with instances of UITextInput.
        inputDelegate?.selectionDidChange(nil)
    }
}

// MARK: - Indent and Outdent
extension TextInputView {
    func shiftLeft() {
        if let selectedRange = selectedRange {
            inputDelegate?.textWillChange(self)
            indentController.shiftLeft(in: selectedRange)
            inputDelegate?.textDidChange(self)
        }
    }

    func shiftRight() {
        if let selectedRange = selectedRange {
            inputDelegate?.textWillChange(self)
            indentController.shiftRight(in: selectedRange)
            inputDelegate?.textDidChange(self)
        }
    }
}

// MARK: - Move Lines
extension TextInputView {
    func moveSelectedLinesUp() {
        moveSelectedLine(byOffset: -1, undoActionName: L10n.Undo.ActionName.moveLinesUp)
    }

    func moveSelectedLinesDown() {
        moveSelectedLine(byOffset: 1, undoActionName: L10n.Undo.ActionName.moveLinesDown)
    }

    private func moveSelectedLine(byOffset lineOffset: Int, undoActionName: String) {
        guard let oldSelectedRange = selectedRange else {
            return
        }
        let moveLinesService = MoveLinesService(stringView: stringView, lineManager: lineManager, lineEndingSymbol: lineEndings.symbol)
        guard let operation = moveLinesService.operationForMovingLines(in: oldSelectedRange, byOffset: lineOffset) else {
            return
        }
        timedUndoManager.endUndoGrouping()
        timedUndoManager.beginUndoGrouping()
        replaceText(in: operation.removeRange, with: "", undoActionName: undoActionName)
        replaceText(in: operation.replacementRange, with: operation.replacementString, undoActionName: undoActionName)
        notifyInputDelegateAboutSelectionChangeInLayoutSubviews = true
        selectedRange = operation.selectedRange
        timedUndoManager.endUndoGrouping()
    }
}

// MARK: - Marking
extension TextInputView {
    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        guard let range = markedRange ?? self.selectedRange else {
            return
        }
        let markedText = markedText ?? ""
        guard shouldChangeText(in: range, replacementText: markedText) else {
            return
        }
        markedRange = markedText.isEmpty ? nil : NSRange(location: range.location, length: markedText.utf16.count)
        replaceText(in: range, with: markedText)
        // The selected range passed to setMarkedText(_:selectedRange:) is local to the marked range.
        let preferredSelectedRange = NSRange(location: range.location + selectedRange.location, length: selectedRange.length)
        inputDelegate?.selectionWillChange(self)
        _selectedRange = safeSelectionRange(from: preferredSelectedRange)
        inputDelegate?.selectionDidChange(self)
        delegate?.textInputViewDidUpdateMarkedRange(self)
    }

    func unmarkText() {
        inputDelegate?.selectionWillChange(self)
        markedRange = nil
        inputDelegate?.selectionDidChange(self)
        delegate?.textInputViewDidUpdateMarkedRange(self)
    }
}

// MARK: - Ranges and Positions
extension TextInputView {
    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        // This implementation seems to match the behavior of UITextView.
        guard let indexedRange = range as? IndexedRange else {
            return nil
        }
        switch direction {
        case .left, .up:
            return IndexedPosition(index: indexedRange.range.lowerBound)
        case .right, .down:
            return IndexedPosition(index: indexedRange.range.upperBound)
        @unknown default:
            return nil
        }
    }

    func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        guard let indexedPosition = position as? IndexedPosition else {
            return nil
        }
        didCallPositionFromPositionInDirectionWithOffset = true
        guard let newLocation = lineMovementController.location(from: indexedPosition.index, in: direction, offset: offset) else {
            return nil
        }
        return IndexedPosition(index: newLocation)
    }

    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        // This implementation seems to match the behavior of UITextView.
        guard let indexedPosition = position as? IndexedPosition else {
            return nil
        }
        switch direction {
        case .left, .up:
            let leftIndex = max(indexedPosition.index - 1, 0)
            return IndexedRange(location: leftIndex, length: indexedPosition.index - leftIndex)
        case .right, .down:
            let rightIndex = min(indexedPosition.index + 1, stringView.string.length)
            return IndexedRange(location: indexedPosition.index, length: rightIndex - indexedPosition.index)
        @unknown default:
            return nil
        }
    }

    func characterRange(at point: CGPoint) -> UITextRange? {
        guard let index = layoutManager.closestIndex(to: point) else {
            return nil
        }
        let cappedIndex = max(index - 1, 0)
        let range = stringView.string.customRangeOfComposedCharacterSequence(at: cappedIndex)
        return IndexedRange(range)
    }

    func closestPosition(to point: CGPoint) -> UITextPosition? {
        if let index = layoutManager.closestIndex(to: point) {
            return IndexedPosition(index: index)
        } else {
            return nil
        }
    }

    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        guard let indexedRange = range as? IndexedRange else {
            return nil
        }
        guard let index = layoutManager.closestIndex(to: point) else {
            return nil
        }
        let minimumIndex = indexedRange.range.lowerBound
        let maximumIndex = indexedRange.range.upperBound
        let cappedIndex = min(max(index, minimumIndex), maximumIndex)
        return IndexedPosition(index: cappedIndex)
    }

    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        guard let fromIndexedPosition = fromPosition as? IndexedPosition, let toIndexedPosition = toPosition as? IndexedPosition else {
            return nil
        }
        let range = NSRange(location: fromIndexedPosition.index, length: toIndexedPosition.index - fromIndexedPosition.index)
        return IndexedRange(range)
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        guard let indexedPosition = position as? IndexedPosition else {
            return nil
        }
        let newPosition = indexedPosition.index + offset
        guard newPosition >= 0 && newPosition <= string.length else {
            return nil
        }
        return IndexedPosition(index: newPosition)
    }

    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        guard let indexedPosition = position as? IndexedPosition, let otherIndexedPosition = other as? IndexedPosition else {
            #if targetEnvironment(macCatalyst)
            // Mac Catalyst may pass <uninitialized> to `position`. I'm not sure what the right way to deal with that is but returning .orderedSame seems to work.
            return .orderedSame
            #else
            fatalError("Positions must be of type \(IndexedPosition.self)")
            #endif
        }
        if indexedPosition.index < otherIndexedPosition.index {
            return .orderedAscending
        } else if indexedPosition.index > otherIndexedPosition.index {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }

    func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int {
        if let fromPosition = from as? IndexedPosition, let toPosition = toPosition as? IndexedPosition {
            return toPosition.index - fromPosition.index
        } else {
            return 0
        }
    }
}

// MARK: - Writing Direction
extension TextInputView {
    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection {
        .natural
    }

    func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {}
}

// MARK: - UIEditMenuInteraction
extension TextInputView {
    func editMenu(for textRange: UITextRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        editMenuController.editMenu(for: textRange, suggestedActions: suggestedActions)
    }

    func presentEditMenuForText(in range: NSRange) {
        editMenuController.presentEditMenu(from: self, forTextIn: range)
    }

    @objc private func replaceTextInSelectedHighlightedRange() {
        if let selectedRange = selectedRange, let highlightedRange = highlightedRange(for: selectedRange) {
            delegate?.textInputView(self, replaceTextIn: highlightedRange)
        }
    }

    private func highlightedRange(for range: NSRange) -> HighlightedRange? {
        highlightedRanges.first { $0.range == range }
    }
}

// MARK: - TreeSitterLanguageModeDeleage
extension TextInputView: TreeSitterLanguageModeDelegate {
    func treeSitterLanguageMode(_ languageMode: TreeSitterInternalLanguageMode, bytesAt byteIndex: ByteCount) -> TreeSitterTextProviderResult? {
        guard byteIndex.value >= 0 && byteIndex < stringView.string.byteCount else {
            return nil
        }
        let targetByteCount: ByteCount = 4 * 1_024
        let endByte = min(byteIndex + targetByteCount, stringView.string.byteCount)
        let byteRange = ByteRange(from: byteIndex, to: endByte)
        if let result = stringView.bytes(in: byteRange) {
            return TreeSitterTextProviderResult(bytes: result.bytes, length: UInt32(result.length.value))
        } else {
            return nil
        }
    }
}

// MARK: - LineControllerStorageDelegate
extension TextInputView: LineControllerStorageDelegate {
    func lineControllerStorage(_ storage: LineControllerStorage, didCreate lineController: LineController) {
        lineController.delegate = self
        lineController.constrainingWidth = layoutManager.constrainingLineWidth
        lineController.estimatedLineFragmentHeight = theme.font.totalLineHeight
        lineController.lineFragmentHeightMultiplier = lineHeightMultiplier
        lineController.tabWidth = indentController.tabWidth
        lineController.theme = theme
        lineController.lineBreakMode = lineBreakMode
    }
}

// MARK: - LineControllerDelegate
extension TextInputView: LineControllerDelegate {
    func lineSyntaxHighlighter(for lineController: LineController) -> LineSyntaxHighlighter? {
        languageMode.createLineSyntaxHighlighter()
    }

    func lineControllerDidInvalidateLineWidthDuringAsyncSyntaxHighlight(_ lineController: LineController) {
        setNeedsLayout()
        layoutManager.setNeedsLayout()
    }
}

// MARK: - LayoutManagerDelegate
extension TextInputView: LayoutManagerDelegate {
    func layoutManager(_ layoutManager: LayoutManager, didProposeContentOffsetAdjustment contentOffsetAdjustment: CGPoint) {
        delegate?.textInputView(self, didProposeContentOffsetAdjustment: contentOffsetAdjustment)
    }
}

// MARK: - IndentControllerDelegate
extension TextInputView: IndentControllerDelegate {
    func indentController(_ controller: IndentController, shouldInsert text: String, in range: NSRange) {
        replaceText(in: range, with: text)
    }

    func indentController(_ controller: IndentController, shouldSelect range: NSRange) {
        inputDelegate?.selectionWillChange(self)
        selectedRange = range
        inputDelegate?.selectionDidChange(self)
    }

    func indentControllerDidUpdateTabWidth(_ controller: IndentController) {
        invalidateLines()
    }
}

// MARK: - EditMenuControllerDelegate
extension TextInputView: EditMenuControllerDelegate {
    func editMenuController(_ controller: EditMenuController, caretRectAt location: Int) -> CGRect {
        caretRectService.caretRect(at: location, allowMovingCaretToNextLineFragment: false)
    }

    func editMenuControllerShouldReplaceText(_ controller: EditMenuController) {
        replaceTextInSelectedHighlightedRange()
    }

    func editMenuController(_ controller: EditMenuController, canReplaceTextIn highlightedRange: HighlightedRange) -> Bool {
        delegate?.textInputView(self, canReplaceTextIn: highlightedRange) ?? false
    }

    func editMenuController(_ controller: EditMenuController, highlightedRangeFor range: NSRange) -> HighlightedRange? {
        highlightedRange(for: range)
    }

    func selectedRange(for controller: EditMenuController) -> NSRange? {
        selectedRange
    }
}
