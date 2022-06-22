// swiftlint:disable file_length
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
            let newRange = (newValue as? IndexedRange)?.range
            if newRange != _selectedRange {
                _selectedRange = newRange
                inputDelegate?.selectionDidChange(self)
                delegate?.textInputViewDidChangeSelection(self)
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
            markedRange = (newValue as? IndexedRange)?.range
        }
    }
    var markedTextStyle: [NSAttributedString.Key: Any]?
    var beginningOfDocument: UITextPosition {
        return IndexedPosition(index: 0)
    }
    var endOfDocument: UITextPosition {
        return IndexedPosition(index: string.length)
    }
    weak var inputDelegate: UITextInputDelegate?
    var hasText: Bool {
        return string.length > 0
    }
    private(set) lazy var tokenizer: UITextInputTokenizer = TextInputStringTokenizer(textInput: self, lineManager: lineManager)
    var autocorrectionType: UITextAutocorrectionType = .default
    var autocapitalizationType: UITextAutocapitalizationType = .sentences
    var smartQuotesType: UITextSmartQuotesType = .default
    var smartDashesType: UITextSmartDashesType = .default
    var smartInsertDeleteType: UITextSmartInsertDeleteType = .default
    var spellCheckingType: UITextSpellCheckingType = .default
    var keyboardType: UIKeyboardType = .default
    var keyboardAppearance: UIKeyboardAppearance = .default
    var returnKeyType: UIReturnKeyType = .default
    @objc var insertionPointColor: UIColor = .black {
        didSet {
            if insertionPointColor != oldValue {
                updateCaretColor()
            }
        }
    }
    @objc var selectionBarColor: UIColor = .black {
        didSet {
            if selectionBarColor != oldValue {
                updateCaretColor()
            }
        }
    }
    @objc var selectionHighlightColor: UIColor = .black.withAlphaComponent(0.2) {
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
        return timedUndoManager
    }

    // MARK: - Appearance
    var theme: Theme {
        didSet {
            lineManager.estimatedLineHeight = estimatedLineHeight
            indentController.indentFont = theme.font
            pageGuideController.font = theme.font
            pageGuideController.guideView.hairlineWidth = theme.pageGuideHairlineWidth
            pageGuideController.guideView.hairlineColor = theme.pageGuideHairlineColor
            pageGuideController.guideView.backgroundColor = theme.pageGuideBackgroundColor
            layoutManager.theme = theme
            layoutManager.tabWidth = indentController.tabWidth
        }
    }
    var showLineNumbers: Bool {
        get {
            return layoutManager.showLineNumbers
        }
        set {
            if newValue != layoutManager.showLineNumbers {
                layoutManager.showLineNumbers = newValue
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var lineSelectionDisplayType: LineSelectionDisplayType {
        get {
            return layoutManager.lineSelectionDisplayType
        }
        set {
            layoutManager.lineSelectionDisplayType = newValue
        }
    }
    var showTabs: Bool {
        get {
            return layoutManager.invisibleCharacterConfiguration.showTabs
        }
        set {
            if newValue != layoutManager.invisibleCharacterConfiguration.showTabs {
                layoutManager.invisibleCharacterConfiguration.showTabs = newValue
                layoutManager.setNeedsDisplayOnLines()
            }
        }
    }
    var showSpaces: Bool {
        get {
            return layoutManager.invisibleCharacterConfiguration.showSpaces
        }
        set {
            if newValue != layoutManager.invisibleCharacterConfiguration.showSpaces {
                layoutManager.invisibleCharacterConfiguration.showSpaces = newValue
                layoutManager.setNeedsDisplayOnLines()
            }
        }
    }
    var showNonBreakingSpaces: Bool {
        get {
            return layoutManager.invisibleCharacterConfiguration.showNonBreakingSpaces
        }
        set {
            if newValue != layoutManager.invisibleCharacterConfiguration.showNonBreakingSpaces {
                layoutManager.invisibleCharacterConfiguration.showNonBreakingSpaces = newValue
                layoutManager.setNeedsDisplayOnLines()
            }
        }
    }
    var showLineBreaks: Bool {
        get {
            return layoutManager.invisibleCharacterConfiguration.showLineBreaks
        }
        set {
            if newValue != layoutManager.invisibleCharacterConfiguration.showLineBreaks {
                layoutManager.invisibleCharacterConfiguration.showLineBreaks = newValue
                layoutManager.invalidateLines()
                layoutManager.setNeedsLayout()
                layoutManager.setNeedsDisplayOnLines()
                setNeedsLayout()
            }
        }
    }
    var showSoftLineBreaks: Bool {
        get {
            return layoutManager.invisibleCharacterConfiguration.showSoftLineBreaks
        }
        set {
            if newValue != layoutManager.invisibleCharacterConfiguration.showSoftLineBreaks {
                layoutManager.invisibleCharacterConfiguration.showSoftLineBreaks = newValue
                layoutManager.invalidateLines()
                layoutManager.setNeedsLayout()
                layoutManager.setNeedsDisplayOnLines()
                setNeedsLayout()
            }
        }
    }
    var tabSymbol: String {
        get {
            return layoutManager.invisibleCharacterConfiguration.tabSymbol
        }
        set {
            if newValue != layoutManager.invisibleCharacterConfiguration.tabSymbol {
                layoutManager.invisibleCharacterConfiguration.tabSymbol = newValue
                layoutManager.setNeedsDisplayOnLines()
            }
        }
    }
    var spaceSymbol: String {
        get {
            return layoutManager.invisibleCharacterConfiguration.spaceSymbol
        }
        set {
            if newValue != layoutManager.invisibleCharacterConfiguration.spaceSymbol {
                layoutManager.invisibleCharacterConfiguration.spaceSymbol = newValue
                layoutManager.setNeedsDisplayOnLines()
            }
        }
    }
    var nonBreakingSpaceSymbol: String {
        get {
            return layoutManager.invisibleCharacterConfiguration.nonBreakingSpaceSymbol
        }
        set {
            if newValue != layoutManager.invisibleCharacterConfiguration.nonBreakingSpaceSymbol {
                layoutManager.invisibleCharacterConfiguration.nonBreakingSpaceSymbol = newValue
                layoutManager.setNeedsDisplayOnLines()
            }
        }
    }
    var lineBreakSymbol: String {
        get {
            return layoutManager.invisibleCharacterConfiguration.lineBreakSymbol
        }
        set {
            if newValue != layoutManager.invisibleCharacterConfiguration.lineBreakSymbol {
                layoutManager.invisibleCharacterConfiguration.lineBreakSymbol = newValue
                layoutManager.setNeedsDisplayOnLines()
            }
        }
    }
    var softLineBreakSymbol: String {
        get {
            return layoutManager.invisibleCharacterConfiguration.softLineBreakSymbol
        }
        set {
            if newValue != layoutManager.invisibleCharacterConfiguration.softLineBreakSymbol {
                layoutManager.invisibleCharacterConfiguration.softLineBreakSymbol = newValue
                layoutManager.setNeedsDisplayOnLines()
            }
        }
    }
    var indentStrategy: IndentStrategy = .tab(length: 2) {
        didSet {
            if indentStrategy != oldValue {
                inputDelegate?.selectionWillChange(self)
                indentController.indentStrategy = indentStrategy
                layoutManager.tabWidth = indentController.tabWidth
                layoutManager.setNeedsLayout()
                setNeedsLayout()
                layoutIfNeeded()
                inputDelegate?.selectionDidChange(self)
            }
        }
    }
    var gutterLeadingPadding: CGFloat {
        get {
            return layoutManager.gutterLeadingPadding
        }
        set {
            if newValue != layoutManager.gutterLeadingPadding {
                layoutManager.gutterLeadingPadding = newValue
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var gutterTrailingPadding: CGFloat {
        get {
            return layoutManager.gutterTrailingPadding
        }
        set {
            if newValue != layoutManager.gutterTrailingPadding {
                layoutManager.gutterTrailingPadding = newValue
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var textContainerInset: UIEdgeInsets {
        get {
            return layoutManager.textContainerInset
        }
        set {
            if newValue != layoutManager.textContainerInset {
                layoutManager.textContainerInset = newValue
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var isLineWrappingEnabled: Bool {
        get {
            return layoutManager.isLineWrappingEnabled
        }
        set {
            if newValue != layoutManager.isLineWrappingEnabled {
                layoutManager.isLineWrappingEnabled = newValue
                layoutManager.invalidateLines()
                layoutManager.setNeedsLayout()
                layoutManager.layoutIfNeeded()
                sendSelectionChangedToTextSelectionView()
            }
        }
    }
    var gutterWidth: CGFloat {
        return layoutManager.gutterWidth
    }
    var lineHeightMultiplier: CGFloat {
        get {
            return layoutManager.lineHeightMultiplier
        }
        set {
            if newValue != layoutManager.lineHeightMultiplier {
                layoutManager.lineHeightMultiplier = newValue
                lineManager.estimatedLineHeight = estimatedLineHeight
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var kern: CGFloat {
        get {
            return layoutManager.kern
        }
        set {
            if newValue != layoutManager.kern {
                pageGuideController.kern = newValue
                layoutManager.kern = newValue
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
            return pageGuideController.column
        }
        set {
            if newValue != pageGuideController.column {
                pageGuideController.column = newValue
                setNeedsLayout()
            }
        }
    }
    private var estimatedLineHeight: CGFloat {
        return theme.font.totalLineHeight * lineHeightMultiplier
    }
    var highlightedRanges: [HighlightedRange] {
        get {
            return layoutManager.highlightedRanges
        }
        set {
            layoutManager.highlightedRanges = newValue
        }
    }

    // MARK: - Contents
    weak var delegate: TextInputViewDelegate?
    var string: NSString {
        get {
            return stringView.string
        }
        set {
            if newValue != stringView.string {
                stringView.string = newValue
                languageMode.parse(newValue)
                lineManager.rebuild(from: newValue)
                if let oldSelectedRange = selectedRange {
                    selectedRange = safeSelectionRange(from: oldSelectedRange)
                }
                layoutManager.invalidateContentSize()
                layoutManager.updateLineNumberWidth()
                layoutManager.invalidateLines()
                layoutManager.setNeedsLayout()
                layoutManager.layoutIfNeeded()
            }
        }
    }
    var viewport: CGRect {
        get {
            return layoutManager.viewport
        }
        set {
            if newValue != layoutManager.viewport {
                layoutManager.viewport = newValue
                layoutManager.setNeedsLayout()
                setNeedsLayout()
            }
        }
    }
    var scrollViewWidth: CGFloat {
        get {
            return layoutManager.scrollViewWidth
        }
        set {
            layoutManager.scrollViewWidth = newValue
        }
    }
    var contentSize: CGSize {
        return layoutManager.contentSize
    }
    var selectedRange: NSRange? {
        get {
            return _selectedRange
        }
        set {
            if newValue != _selectedRange {
                inputDelegate?.selectionWillChange(self)
                _selectedRange = newValue
                inputDelegate?.selectionDidChange(self)
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
        return true
    }
    weak var scrollView: UIScrollView? {
        get {
            return layoutManager.scrollView
        }
        set {
            layoutManager.scrollView = newValue
        }
    }
    var gutterContainerView: UIView {
        return layoutManager.gutterContainerView
    }
    private(set) var stringView = StringView() {
        didSet {
            if stringView !== oldValue {
                lineManager.stringView = stringView
                layoutManager.stringView = stringView
                indentController.stringView = stringView
                lineMovementController.stringView = stringView
            }
        }
    }
    private(set) var lineManager: LineManager {
        didSet {
            if lineManager !== oldValue {
                indentController.lineManager = lineManager
                lineMovementController.lineManager = lineManager
            }
        }
    }
    var viewHierarchyContainsCaret: Bool {
        return textSelectionView?.subviews.count == 1
    }
    var lineEndings: LineEnding = .lf

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
    private let layoutManager: LayoutManager
    private let timedUndoManager = TimedUndoManager()
    private let indentController: IndentController
    private let lineMovementController: LineMovementController
    private let pageGuideController = PageGuideController()
    private var markedRange: NSRange? {
        get {
            return layoutManager.markedRange
        }
        set {
            layoutManager.markedRange = newValue
        }
    }
    private var floatingCaretView: FloatingCaretView?
    private var insertionPointColorBeforeFloatingBegan: UIColor = .black
    private var maximumLeadingCharacterPairComponentLength = 0
    private var textSelectionView: UIView? {
        if let klass = NSClassFromString("UITextSelectionView") {
            for subview in subviews {
                if subview.isKind(of: klass) {
                    return subview
                }
            }
        }
        return nil
    }
    private var hasPendingFullLayout = false

    // MARK: - Lifecycle
    init(theme: Theme) {
        self.theme = theme
        lineManager = LineManager(stringView: stringView)
        layoutManager = LayoutManager(lineManager: lineManager, languageMode: languageMode, stringView: stringView)
        indentController = IndentController(
            stringView: stringView,
            lineManager: lineManager,
            languageMode: languageMode,
            indentStrategy: indentStrategy,
            indentFont: theme.font)
        lineMovementController = LineMovementController(lineManager: lineManager, stringView: stringView)
        super.init(frame: .zero)
        lineManager.estimatedLineHeight = estimatedLineHeight
        indentController.delegate = self
        lineMovementController.delegate = self
        layoutManager.delegate = self
        layoutManager.textInputView = self
        layoutManager.theme = theme
        layoutManager.tabWidth = indentController.tabWidth
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
        layoutManager.layoutIfNeeded()
        layoutManager.layoutLineSelectionIfNeeded()
        layoutPageGuideIfNeeded()
    }

    override func copy(_ sender: Any?) {
        if let selectedTextRange = selectedTextRange, let text = text(in: selectedTextRange) {
            UIPasteboard.general.string = text
        }
    }

    override func paste(_ sender: Any?) {
        if let selectedTextRange = selectedTextRange, let string = UIPasteboard.general.string {
            let preparedText = prepareTextForInsertion(string)
            inputDelegate?.selectionWillChange(self)
            replace(selectedTextRange, withText: preparedText)
            inputDelegate?.selectionDidChange(self)
        }
    }

    override func cut(_ sender: Any?) {
        if let selectedTextRange = selectedTextRange, let text = text(in: selectedTextRange) {
            UIPasteboard.general.string = text
            inputDelegate?.selectionWillChange(self)
            replace(selectedTextRange, withText: "")
            inputDelegate?.selectionDidChange(self)
        }
    }

    override func selectAll(_ sender: Any?) {
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
        } else {
            return super.canPerformAction(action, withSender: sender)
        }
    }

    func linePosition(at location: Int) -> LinePosition? {
        return lineManager.linePosition(at: location)
    }

    func setState(_ state: TextViewState, addUndoAction: Bool = false) {
        let oldText = stringView.string
        let newText = state.stringView.string
        stringView = state.stringView
        theme = state.theme
        languageMode = state.languageMode
        lineManager = state.lineManager
        lineManager.estimatedLineHeight = estimatedLineHeight
        layoutManager.languageMode = state.languageMode
        layoutManager.lineManager = state.lineManager
        layoutManager.invalidateContentSize()
        layoutManager.updateLineNumberWidth()
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
                self.layoutManager.invalidateLines()
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
        return languageMode.detectIndentStrategy()
    }

    func textPreview(containing range: NSRange) -> TextPreview? {
        return layoutManager.textPreview(containing: range)
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
            layoutManager.invalidateLines()
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
            let maxContentOffsetX = layoutManager.contentSize.width - viewport.width
            let widthExtension = max(ceil(viewport.minX - maxContentOffsetX), 0)
            let xPosition = layoutManager.gutterWidth + textContainerInset.left + pageGuideController.columnOffset
            let width = max(bounds.width - xPosition + widthExtension, 0)
            let orrigin = CGPoint(x: xPosition, y: viewport.minY)
            let pageGuideSize = CGSize(width: width, height: viewport.height)
            pageGuideController.guideView.frame = CGRect(origin: orrigin, size: pageGuideSize)
        }
    }

    private func performFullLayout() {
        inputDelegate?.selectionWillChange(self)
        layoutManager.invalidateLines()
        layoutManager.setNeedsLayout()
        layoutManager.layoutIfNeeded()
        inputDelegate?.selectionDidChange(self)
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
        return caretRect(at: indexedPosition.index)
    }

    func caretRect(at location: Int) -> CGRect {
        return layoutManager.caretRect(at: location)
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
        // If there is no marked range or selected range then we fallback to appending text to the end of our string.
        let selectedRange = markedRange ?? selectedRange ?? NSRange(location: stringView.string.length, length: 0)
        guard shouldChangeText(in: selectedRange, replacementText: preparedText) else {
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
            delegate?.textInputViewDidChangeSelection(self)
        }
    }

    func deleteBackward() {
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
        return stringView.substring(in: range)
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
        string = newString
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
        layoutIfNeeded()
        delegate?.textInputViewDidChange(self)
        if updatedTextEditResult.didAddOrRemoveLines {
            delegate?.textInputViewDidInvalidateContentSize(self)
        }
    }

    private func applyLineChangesToLayoutManager(_ lineChangeSet: LineChangeSet) {
        let didAddOrRemoveLines = !lineChangeSet.insertedLines.isEmpty || !lineChangeSet.removedLines.isEmpty
        if didAddOrRemoveLines {
            layoutManager.invalidateContentSize()
            for removedLine in lineChangeSet.removedLines {
                layoutManager.removeLine(withID: removedLine.id)
            }
        }
        let editedLineIDs = Set(lineChangeSet.editedLines.map(\.id))
        layoutManager.redisplayLines(withIDs: editedLineIDs)
        if didAddOrRemoveLines {
            layoutManager.updateLineNumberWidth()
        }
        layoutManager.setNeedsLayout()
        layoutManager.layoutIfNeeded()
    }

    private func shouldChangeText(in range: NSRange, replacementText text: String) -> Bool {
        return delegate?.textInputView(self, shouldChangeTextIn: range, replacementText: text) ?? true
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
            textInputView.inputDelegate?.selectionDidChange(textInputView)
            textInputView.selectedRange = oldSelectedRange
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
            return layoutManager.selectionRects(in: indexedRange.range.nonNegativeLength)
        } else {
            return []
        }
    }

    private func safeSelectionRange(from range: NSRange) -> NSRange {
        let cappedLocation = min(max(range.location, 0), stringView.string.length)
        let cappedLength = min(max(range.length, 0), stringView.string.length - cappedLocation)
        return NSRange(location: cappedLocation, length: cappedLength)
    }

    func sendSelectionChangedToTextSelectionView() {
        // Fores the position of the caret to be updated. Normally we can do this by notifying the input delegate when changing the selected range like:
        //
        // inputDelegate?.selectionWillChange(self)
        // selectedRange = newSelectedRange
        // inputDelegate?.selectionDidChange(self)
        //
        // If we don't notify the input delegate when the setter on selectedTextRange is called, then the location of the caret will not be updated.
        // However, if we do notify the delegate when the setter is called, Korean input will no longer work as described in https://github.com/simonbs/Runestone/issues/11
        // So the workaround is to not notify the delegate but tell the text selection view directly that the selection has changed.
        if let textSelectionView = textSelectionView {
            let sel = NSSelectorFromString("selectionChanged")
            if textSelectionView.responds(to: sel) {
                textSelectionView.perform(sel)
            } else {
                print("\(textSelectionView) does not respond to 'selectionChanged'")
            }
        }
    }

    private func moveCaret(to linePosition: LinePosition) {
        // By restoring the selected range using the old line position we can better preserve the old selected language.
        let line = lineManager.line(atRow: linePosition.row)
        let location = line.location + min(linePosition.column, line.data.length)
        selectedRange = NSRange(location: location, length: 0)
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
        // This implementation of moving lines is naive, as it first removes the selected lines and then insertes the text at the target line.
        // That requires two parses of the syntax tree and two operations on our line manager. Ideally we would do this in one operation.
        let isMovingDown = lineOffset > 0
        guard let oldSelectedRange = selectedRange else {
            return
        }
        let selectedLines = lineManager.lines(in: oldSelectedRange)
        guard !selectedLines.isEmpty else {
            return
        }
        let firstLine = selectedLines[0]
        let lastLine = selectedLines[selectedLines.count - 1]
        let firstLineIndex = firstLine.index
        var targetLineIndex = firstLineIndex + lineOffset
        if isMovingDown {
            targetLineIndex += selectedLines.count - 1
        }
        guard targetLineIndex >= 0 && targetLineIndex < lineManager.lineCount else {
            return
        }
        // Find the line to move the selected text to.
        let targetLine = lineManager.line(atRow: targetLineIndex)
        // Find the range of text to remove. That's the range encapsulating selected lines.
        let removeLocation = firstLine.location
        let removeLength: Int
        if firstLine === lastLine {
            removeLength = firstLine.data.totalLength
        } else {
            removeLength = lastLine.location + lastLine.data.totalLength - removeLocation
        }
        // Find the location to insert the text at.
        var insertLocation = targetLine.location
        if isMovingDown {
            insertLocation += targetLine.data.totalLength - removeLength
        }
        // Perform the remove and insert operations.
        let removeRange = NSRange(location: removeLocation, length: removeLength)
        let insertRange = NSRange(location: insertLocation, length: 0)
        if var text = stringView.substring(in: removeRange) {
            timedUndoManager.endUndoGrouping()
            timedUndoManager.beginUndoGrouping()
            if lastLine.data.delimiterLength == 0 {
                text += lineEndings.symbol
            }
            replaceText(in: removeRange, with: "", undoActionName: undoActionName)
            replaceText(in: insertRange, with: text, undoActionName: undoActionName)
            // Update the selected range to match the old one but at the new lines.
            let locationOffset = insertLocation - removeLocation
            selectedRange = NSRange(location: oldSelectedRange.location + locationOffset, length: oldSelectedRange.length)
            timedUndoManager.endUndoGrouping()
        }
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
        inputDelegate?.selectionWillChange(self)
        replaceText(in: range, with: markedText)
        inputDelegate?.selectionDidChange(self)
        delegate?.textInputViewDidUpdateMarkedRange(self)
    }

    func unmarkText() {
        markedRange = nil
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
        guard let location = lineMovementController.location(from: indexedPosition.index, in: direction, offset: offset) else {
            return nil
        }
        return IndexedPosition(index: location)
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
        return .natural
    }

    func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {}
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

// MARK: - LayoutManagerDelegate
extension TextInputView: LayoutManagerDelegate {
    func layoutManagerDidInvalidateContentSize(_ layoutManager: LayoutManager) {
        delegate?.textInputViewDidInvalidateContentSize(self)
    }

    func layoutManager(_ layoutManager: LayoutManager, didProposeContentOffsetAdjustment contentOffsetAdjustment: CGPoint) {
        delegate?.textInputView(self, didProposeContentOffsetAdjustment: contentOffsetAdjustment)
    }

    func layoutManagerDidChangeGutterWidth(_ layoutManager: LayoutManager) {
        // Typeset lines again when the line number width changes.
        // Changing line number width may increase or reduce the number of line fragments in a line.
        setNeedsLayout()
        layoutManager.invalidateLines()
        layoutManager.setNeedsLayout()
        delegate?.textInputViewDidChangeGutterWidth(self)
    }

    func layoutManagerDidInvalidateLineWidthDuringAsyncSyntaxHighlight(_ layoutManager: LayoutManager) {
        setNeedsLayout()
        layoutManager.setNeedsLayout()
    }
}

// MARK: - IndentControllerDelegate
extension TextInputView: IndentControllerDelegate {
    func indentController(_ controller: IndentController, shouldInsert text: String, in range: NSRange) {
        replaceText(in: range, with: text)
    }

    func indentController(_ controller: IndentController, shouldSelect range: NSRange) {
        selectedRange = range
    }
}

// MARK: - LineMovementControllerDelegate
extension TextInputView: LineMovementControllerDelegate {
    func lineMovementController(_ controller: LineMovementController, numberOfLineFragmentsIn line: DocumentLineNode) -> Int {
        return layoutManager.numberOfLineFragments(in: line)
    }

    func lineMovementController(_ controller: LineMovementController,
                                lineFragmentNodeAtIndex index: Int,
                                in line: DocumentLineNode) -> LineFragmentNode {
        return layoutManager.lineFragmentNode(atIndex: index, in: line)
    }

    func lineMovementController(_ controller: LineMovementController,
                                lineFragmentNodeContainingCharacterAt location: Int,
                                in line: DocumentLineNode) -> LineFragmentNode {
        return layoutManager.lineFragmentNode(containingCharacterAt: location, in: line)
    }
}
