//
//  TextInputView.swift
//  
//
//  Created by Simon Støvring on 05/01/2021.
//

// swiftlint:disable file_length

import UIKit

protocol TextInputViewDelegate: AnyObject {
    func textInputViewWillBeginEditing(_ view: TextInputView)
    func textInputViewDidBeginEditing(_ view: TextInputView)
    func textInputViewDidEndEditing(_ view: TextInputView)
    func textInputViewDidChange(_ view: TextInputView)
    func textInputViewDidChangeSelection(_ view: TextInputView)
    func textInputView(_ view: TextInputView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
    func textInputViewDidInvalidateContentSize(_ view: TextInputView)
    func textInputView(_ view: TextInputView, didProposeContentOffsetAdjustment contentOffsetAdjustment: CGPoint)
    func textInputViewDidUpdateGutterWidth(_ view: TextInputView)
    func textInputViewDidBeginFloatingCursor(_ view: TextInputView)
    func textInputViewDidEndFloatingCursor(_ view: TextInputView)
}

// swiftlint:disable:next type_body_length
final class TextInputView: UIView, UITextInput {
    private enum UndoCaretBehavior {
        case `default`
        case preserve
    }

    // MARK: - UITextInput
    var selectedTextRange: UITextRange? {
        get {
            if let range = selectedRange {
                return IndexedRange(range)
            } else {
                return nil
            }
        }
        set {
            if let newRange = (newValue as? IndexedRange)?.range {
                if newRange != selectedRange {
                    inputDelegate?.selectionWillChange(self)
                    selectedRange = newRange
                    inputDelegate?.selectionDidChange(self)
                    delegate?.textInputViewDidChangeSelection(self)
                }
            } else {
                selectedRange = nil
            }
        }
    }
    private(set) var markedTextRange: UITextRange?
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
    @objc var selectionHighlightColor: UIColor = .black {
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
                layoutManager.invalidateAndUpdateImageOnLines()
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
                layoutManager.invalidateAndUpdateImageOnLines()
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
                layoutManager.invalidateAndUpdateImageOnLines()
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
                layoutManager.invalidateAndUpdateImageOnLines()
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
                layoutManager.invalidateAndUpdateImageOnLines()
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
                layoutManager.invalidateAndUpdateImageOnLines()
            }
        }
    }
    var indentStrategy: IndentStrategy = .tab(length: 2) {
        didSet {
            if indentStrategy != oldValue {
                indentController.indentStrategy = indentStrategy
                layoutManager.tabWidth = indentController.tabWidth
                layoutManager.setNeedsLayout()
                setNeedsLayout()
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
                setNeedsLayout()
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
                performSelectionModifyingChanges {
                    layoutManager.lineHeightMultiplier = newValue
                    lineManager.estimatedLineHeight = estimatedLineHeight
                }
            }
        }
    }
    var kern: CGFloat {
        get {
            return layoutManager.kern
        }
        set {
            if newValue != layoutManager.kern {
                performSelectionModifyingChanges {
                    layoutManager.kern = newValue
                }
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
                inputDelegate?.selectionWillChange(self)
                if let selectedRange = selectedRange {
                    let cappedLocation = min(max(selectedRange.location, 0), stringView.string.length)
                    let cappedLength = min(max(selectedRange.length, 0), stringView.string.length - cappedLocation)
                    self.selectedRange = NSRange(location: cappedLocation, length: cappedLength)
                }
                layoutManager.invalidateContentSize()
                layoutManager.updateLineNumberWidth()
                layoutManager.invalidateLines()
                layoutManager.setNeedsLayout()
                layoutManager.layoutIfNeeded()
                inputDelegate?.selectionDidChange(self)
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
    var scrollViewSafeAreaInsets: UIEdgeInsets {
        get {
            return layoutManager.scrollViewSafeAreaInsets
        }
        set {
            layoutManager.scrollViewSafeAreaInsets = newValue
        }
    }
    var contentSize: CGSize {
        return layoutManager.contentSize
    }
    private(set) var selectedRange: NSRange? {
        didSet {
            if selectedRange != oldValue {
                layoutManager.selectedRange = selectedRange
                layoutManager.setNeedsLayoutSelection()
                setNeedsLayout()
            }
        }
    }
    override var canBecomeFirstResponder: Bool {
        return true
    }
    weak var editorView: UIScrollView? {
        get {
            return layoutManager.editorView
        }
        set {
            layoutManager.editorView = newValue
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
    private var markedRange: NSRange?
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
        layoutManager.layoutSelectionIfNeeded()
        layoutPageGuideIfNeeded()
    }

    override func copy(_ sender: Any?) {
        if let selectedTextRange = selectedTextRange, let text = text(in: selectedTextRange) {
            UIPasteboard.general.string = text
        }
    }

    override func paste(_ sender: Any?) {
        if let selectedTextRange = selectedTextRange, let string = UIPasteboard.general.string {
            inputDelegate?.selectionWillChange(self)
            replace(selectedTextRange, withText: string)
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
        inputDelegate?.selectionWillChange(self)
        selectedRange = NSRange(location: 0, length: string.length)
        inputDelegate?.selectionDidChange(self)
        delegate?.textInputViewDidChangeSelection(self)
    }

    /// When autocorrection is enabled and the user tap on a misspelled word, UITextInteraction will present
    /// a UIMenuController with suggestions for the correct spelling of the word. Selecting a suggestion will
    /// cause UITextInteraction to call the non-existing -replace(_:) function and pass an instance of the private
    /// UITextReplacement type as parameter. We can't make autocorrection work properly without using private API.
    @objc func replace(_ obj: NSObject) {
        if let replacementText = obj.value(forKey: "_repl" + "Ttnemeca".reversed() + "ext") as? String {
            if let indexedRange = obj.value(forKey: "_r" + "gna".reversed() + "e") as? IndexedRange {
                inputDelegate?.selectionWillChange(self)
                replace(indexedRange, withText: replacementText)
                inputDelegate?.selectionDidChange(self)
            }
        }
    }

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(copy(_:)) || action == #selector(cut(_:)) {
            if let selectedTextRange = selectedTextRange {
                return !selectedTextRange.isEmpty
            } else {
                return false
            }
        } else if action == #selector(paste(_:)) {
            return UIPasteboard.general.hasStrings
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
                addUndoOperation(replacing: newRange, withText: oldText as String, caretBehavior: .preserve)
                timedUndoManager.endUndoGrouping()
            }
        } else {
            timedUndoManager.removeAllActions()
        }
        if window != nil {
            inputDelegate?.selectionWillChange(self)
            layoutManager.invalidateLines()
            layoutManager.setNeedsLayout()
            layoutManager.layoutIfNeeded()
            inputDelegate?.selectionDidChange(self)
        }
    }

    func moveCaret(to point: CGPoint) {
        if let index = layoutManager.closestIndex(to: point) {
            selectedTextRange = IndexedRange(location: index, length: 0)
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
                self.inputDelegate?.selectionWillChange(self)
                self.layoutManager.invalidateLines()
                self.layoutManager.setNeedsLayout()
                self.layoutManager.layoutIfNeeded()
                self.inputDelegate?.selectionDidChange(self)
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

    func layoutLines(untilLocation location: Int) {
        layoutManager.layoutLines(untilLocation: location)
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
}

// MARK: - Layout
private extension TextInputView {
    private func layoutPageGuideIfNeeded() {
        if showPageGuide {
            // The width extension is used to make the page guide look "attached" to the right hand side,
            // even when the scroll view bouncing on the right side.
            let maxContentOffsetX = layoutManager.contentSize.width - viewport.width
            let widthExtension = max(ceil(viewport.minX - maxContentOffsetX), 0)
            let xPosition = layoutManager.gutterWidth + textContainerInset.left + pageGuideController.columnOffset
            let width = max(bounds.width - xPosition + widthExtension, 0)
            let orrigin = CGPoint(x: xPosition, y: viewport.minY)
            let pageGuideSize = CGSize(width: width, height: viewport.height)
            pageGuideController.guideView.frame = CGRect(origin: orrigin, size: pageGuideSize)
        }
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
        if let selectedRange = selectedRange, shouldChangeText(in: selectedRange, replacementText: text) {
            if let lineBreak = IndentController.LineBreak(rawValue: text) {
                inputDelegate?.selectionWillChange(self)
                indentController.insertLineBreak(in: selectedRange, using: lineBreak)
                layoutIfNeeded()
                inputDelegate?.selectionDidChange(self)
                delegate?.textInputViewDidChangeSelection(self)
            } else {
                replaceCharactersAndNotifyDelegate(replacing: selectedRange, with: text)
            }
        }
    }

    func deleteBackward() {
        if let selectedRange = selectedRange, selectedRange.length > 0 {
            let deleteRange = rangeForDeletingText(in: selectedRange)
            if shouldChangeText(in: deleteRange, replacementText: "") {
                replaceCharactersAndNotifyDelegate(replacing: deleteRange, with: "")
            }
        }
    }

    func replace(_ range: UITextRange, withText text: String) {
        if let indexedRange = range as? IndexedRange, shouldChangeText(in: indexedRange.range, replacementText: text) {
            replaceCharactersAndNotifyDelegate(replacing: indexedRange.range, with: text)
        }
    }

    func replaceText(in batchReplaceSet: BatchReplaceSet) {
        guard !batchReplaceSet.matches.isEmpty else {
            return
        }
        timedUndoManager.endUndoGrouping()
        let oldSelectedRange = selectedRange
        let sortedMatches = batchReplaceSet.matches.sorted { $0.range.location < $1.range.location }
        var replacedRanges: [NSRange] = []
        var undoMatches: [BatchReplaceSet.Match] = []
        var totalChangeInLength = 0
        var didAddOrRemoveLines = false
        for result in sortedMatches where !replacedRanges.contains(where: { $0.overlaps(result.range) }) {
            let range = result.range
            let adjustedRange = NSRange(location: range.location + totalChangeInLength, length: range.length)
            let existingText = stringView.substring(in: adjustedRange) ?? ""
            let nsReplacementText = result.replacementText as NSString
            let localDidAddOrRemoveLines = justReplaceCharacters(in: adjustedRange, with: nsReplacementText)
            if localDidAddOrRemoveLines {
                didAddOrRemoveLines = true
            }
            let undoRange = NSRange(location: adjustedRange.location, length: nsReplacementText.length)
            let undoMatch = BatchReplaceSet.Match(range: undoRange, replacementText: existingText)
            replacedRanges.append(range)
            undoMatches.append(undoMatch)
            totalChangeInLength += result.replacementText.utf16.count - range.length
        }
        delegate?.textInputViewDidChange(self)
        if didAddOrRemoveLines {
            delegate?.textInputViewDidInvalidateContentSize(self)
        }
        let undoBatchReplaceSet = BatchReplaceSet(matches: undoMatches)
        timedUndoManager.beginUndoGrouping()
        timedUndoManager.setActionName(L10n.Undo.ActionName.replaceAll)
        timedUndoManager.registerUndo(withTarget: self) { textInputView in
            textInputView.replaceText(in: undoBatchReplaceSet)
        }
        timedUndoManager.endUndoGrouping()
        if let oldSelectedRange = oldSelectedRange {
            if oldSelectedRange.location < stringView.string.length {
                selectedRange = NSRange(location: oldSelectedRange.location, length: 0)
            } else {
                selectedRange = NSRange(location: stringView.string.length, length: 0)
            }
        }
    }

    func text(in range: UITextRange) -> String? {
        if let indexedRange = range as? IndexedRange {
            return text(in: indexedRange.range)
        } else {
            return nil
        }
    }

    func text(in range: NSRange) -> String? {
        return stringView.substring(in: range)
    }

    private func rangeForDeletingText(in range: NSRange) -> NSRange {
        var resultingRange = range
        if range.length == 1, let indentRange = indentController.indentRangeInFrontOfLocation(range.upperBound) {
            resultingRange = indentRange
        } else {
            resultingRange = string.rangeOfComposedCharacterSequences(for: range)
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

    private func replaceCharactersAndNotifyDelegate(replacing range: NSRange, with text: String, undoCaretBehavior: UndoCaretBehavior = .default) {
        inputDelegate?.selectionWillChange(self)
        let didAddOrRemoveLines = replaceCharacters(in: range, with: text, undoCaretBehavior: undoCaretBehavior)
        layoutIfNeeded()
        delegate?.textInputViewDidChange(self)
        if didAddOrRemoveLines {
            delegate?.textInputViewDidInvalidateContentSize(self)
        }
        inputDelegate?.selectionDidChange(self)
        delegate?.textInputViewDidChangeSelection(self)
    }

    private func replaceCharacters(in range: NSRange, with text: String, undoCaretBehavior: UndoCaretBehavior = .default) -> Bool {
        let nsText = text as NSString
        let currentText = self.text(in: range) ?? ""
        let newRange = NSRange(location: range.location, length: nsText.length)
        addUndoOperation(replacing: newRange, withText: currentText, caretBehavior: undoCaretBehavior)
        selectedRange = NSRange(location: newRange.upperBound, length: 0)
        return justReplaceCharacters(in: range, with: nsText)
    }

    private func justReplaceCharacters(in range: NSRange, with nsNewString: NSString) -> Bool {
        let byteRange = ByteRange(utf16Range: range)
        let newString = nsNewString as String
        let oldEndLinePosition = lineManager.linePosition(at: range.location + range.length)!
        stringView.replaceCharacters(in: range, with: newString)
        let changeSet = LineChangeSet()
        let changeSetFromRemovingCharacters = lineManager.removeCharacters(in: range)
        changeSet.union(with: changeSetFromRemovingCharacters)
        let changeSetFromInsertingCharacters = lineManager.insert(nsNewString, at: range.location)
        changeSet.union(with: changeSetFromInsertingCharacters)
        // Tell the language mode that the text have changed so it can prepare for syntax highlighting.
        let startLinePosition = lineManager.linePosition(at: range.location)!
        let newEndLinePosition = lineManager.linePosition(at: range.location + nsNewString.length)!
        let textChange = LanguageModeTextChange(
            byteRange: byteRange,
            newString: newString,
            oldEndLinePosition: oldEndLinePosition,
            startLinePosition: startLinePosition,
            newEndLinePosition: newEndLinePosition)
        let result = languageMode.textDidChange(textChange)
        // Update the change set with changes performed by the language mode.
        let languageModeEditedLines = result.changedRows.map { lineManager.line(atRow: $0) }
        for editedLine in languageModeEditedLines {
            changeSet.markLineEdited(editedLine)
        }
        // Invalidate lines if necessary.
        let didAddOrRemoveLines = !changeSet.insertedLines.isEmpty || !changeSet.removedLines.isEmpty
        if didAddOrRemoveLines {
            layoutManager.invalidateContentSize()
            for removedLine in changeSet.removedLines {
                layoutManager.removeLine(withID: removedLine.id)
            }
        }
        layoutManager.redisplay(changeSet.editedLines)
        if didAddOrRemoveLines {
            layoutManager.updateLineNumberWidth()
        }
        layoutManager.setNeedsLayout()
        layoutManager.layoutIfNeeded()
        return didAddOrRemoveLines
    }

    private func shouldChangeText(in range: NSRange, replacementText text: String) -> Bool {
        return delegate?.textInputView(self, shouldChangeTextIn: range, replacementText: text) ?? true
    }

    private func addUndoOperation(replacing range: NSRange, withText text: String, caretBehavior: UndoCaretBehavior = .default) {
        let oldSelectedRange = selectedRange
        timedUndoManager.beginUndoGrouping()
        timedUndoManager.setActionName(L10n.Undo.ActionName.typing)
        timedUndoManager.registerUndo(withTarget: self) { textInputView in
            self.inputDelegate?.selectionWillChange(self)
            let indexedRange = IndexedRange(range)
            let didAddOrRemoveLines = textInputView.replaceCharacters(in: indexedRange.range, with: text, undoCaretBehavior: caretBehavior)
            switch caretBehavior {
            case .default:
                let textLength = text.utf16.count
                if range.length > 0 && textLength > 0 {
                    self.selectedRange = NSRange(location: range.location, length: textLength)
                }
            case .preserve:
                if let oldSelectedRange = oldSelectedRange, oldSelectedRange.location >= self.stringView.string.length {
                    self.selectedRange = NSRange(location: self.stringView.string.length, length: 0)
                } else {
                    self.selectedRange = oldSelectedRange
                }
            }
            self.layoutIfNeeded()
            self.inputDelegate?.selectionDidChange(self)
            self.delegate?.textInputViewDidChange(self)
            if didAddOrRemoveLines {
                self.delegate?.textInputViewDidInvalidateContentSize(self)
            }
            self.delegate?.textInputViewDidChangeSelection(self)
        }
    }
}

// MARK: - Selection
extension TextInputView {
    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        if let indexedRange = range as? IndexedRange {
            return layoutManager.selectionRects(in: indexedRange.range)
        } else {
            return []
        }
    }

    private func performSelectionModifyingChanges(_ changes: () -> Void) {
        // Notify the delegate that the selection may change as the position
        // of the caret will change when we adjust the width or height of lines.
        inputDelegate?.selectionWillChange(self)
        changes()
        layoutManager.setNeedsLayout()
        inputDelegate?.selectionDidChange(self)
        // Do a layout pass to ensure the position of the caret is correct.
        setNeedsLayout()
    }
}

// MARK: - Indent and Outdent
extension TextInputView {
    func shiftLeft() {
        if let selectedRange = selectedRange {
            inputDelegate?.selectionWillChange(self)
            inputDelegate?.textWillChange(self)
            indentController.shiftLeft(in: selectedRange)
            inputDelegate?.textDidChange(self)
            inputDelegate?.selectionDidChange(self)
            delegate?.textInputViewDidChangeSelection(self)
        }
    }

    func shiftRight() {
        if let selectedRange = selectedRange {
            inputDelegate?.selectionWillChange(self)
            inputDelegate?.textWillChange(self)
            indentController.shiftRight(in: selectedRange)
            inputDelegate?.textDidChange(self)
            inputDelegate?.selectionDidChange(self)
            delegate?.textInputViewDidChangeSelection(self)
        }
    }
}

// MARK: - Marking
extension TextInputView {
    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {}

    func unmarkText() {}
}

// MARK: - Ranges and Positions
extension TextInputView {
    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        return nil
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
        return nil
    }

    func characterRange(at point: CGPoint) -> UITextRange? {
        return nil
    }

    func closestPosition(to point: CGPoint) -> UITextPosition? {
        if let index = layoutManager.closestIndex(to: point) {
            return IndexedPosition(index: index)
        } else {
            return nil
        }
    }

    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        return nil
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
            fatalError("Positions must be of type \(IndexedPosition.self)")
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
        let targetCharacterCount = 4 * 1_024
        let startLocation = byteIndex.utf16Length
        let endLocation = min(startLocation + targetCharacterCount, stringView.string.length - 1)
        let startRange = string.rangeOfComposedCharacterSequence(at: startLocation)
        let endRange = string.rangeOfComposedCharacterSequence(at: endLocation)
        let byteLocation = ByteCount(utf16Length: startRange.location)
        let byteLength = ByteCount(utf16Length: endRange.upperBound - startRange.lowerBound)
        let byteRange = ByteRange(location: byteLocation, length: byteLength)
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

    func layoutManagerDidUpdateGutterWidth(_ layoutManager: LayoutManager) {
        // Typeset lines again when the line number width changes.
        // Changing line number width may increase or reduce the number of line fragments in a line.
        setNeedsLayout()
        layoutManager.invalidateLines()
        layoutManager.setNeedsLayout()
        delegate?.textInputViewDidUpdateGutterWidth(self)
    }

    func layoutManagerDidInvalidateLineWidthDuringAsyncSyntaxHighlight(_ layoutManager: LayoutManager) {
        setNeedsLayout()
        layoutManager.setNeedsLayout()
    }
}

// MARK: - IndentControllerDelegate
extension TextInputView: IndentControllerDelegate {
    func indentController(_ controller: IndentController, shouldInsert text: String, in range: NSRange) {
        replaceCharactersAndNotifyDelegate(replacing: range, with: text)
    }

    func indentController(_ controller: IndentController, shouldSelect range: NSRange) {
        if range != selectedRange {
            selectedTextRange = IndexedRange(range)
        }
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
