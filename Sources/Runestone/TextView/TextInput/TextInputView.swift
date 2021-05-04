//
//  TextInputView.swift
//  
//
//  Created by Simon Støvring on 05/01/2021.
//

import UIKit

public enum GoToLineSelection {
    case beginning
    case end
    case line
}

protocol TextInputViewDelegate: AnyObject {
    func textInputViewDidChange(_ view: TextInputView)
    func textInputViewDidChangeSelection(_ view: TextInputView)
    func textInputView(_ view: TextInputView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
    func textInputViewDidInvalidateContentSize(_ view: TextInputView)
    func textInputView(_ view: TextInputView, didProposeContentOffsetAdjustment contentOffsetAdjustment: CGPoint)
    func textInputViewDidUpdateGutterWidth(_ view: TextInputView)
    func textInputViewDidBeginFloatingCursor(_ view: TextInputView)
    func textInputViewDidEndFloatingCursor(_ view: TextInputView)
}

final class TextInputView: UIView, UITextInput {
    private struct ParsedLine {
        let startByte: ByteCount
        let byteCount: ByteCount
        var endByte: ByteCount {
            return startByte + byteCount
        }
        let lineRange: NSRange
        let lineString: String
    }

    // MARK: - UITextInput
    var selectedTextRange: UITextRange? {
        get {
            if let range = selectedRange {
                return IndexedRange(range: range)
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
    var inputDelegate: UITextInputDelegate?
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
                layoutIfNeeded()
            }
        }
    }
    var showSelectedLines: Bool {
        get {
            return layoutManager.showSelectedLines
        }
        set {
            layoutManager.showSelectedLines = newValue
        }
    }
    var showTabs: Bool {
        get {
            return layoutManager.invisibleCharacterConfiguration.showTabs
        }
        set {
            if newValue != layoutManager.invisibleCharacterConfiguration.showTabs {
                layoutManager.invisibleCharacterConfiguration.showTabs = newValue
                layoutManager.invalidateLines()
                layoutManager.setNeedsLayout()
                layoutManager.layoutIfNeeded()
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
                layoutManager.invalidateLines()
                layoutManager.setNeedsLayout()
                layoutManager.layoutIfNeeded()
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
                setNeedsLayout()
                layoutIfNeeded()
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
                layoutManager.invalidateLines()
                layoutManager.setNeedsLayout()
                setNeedsLayout()
                layoutIfNeeded()
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
                layoutManager.invalidateLines()
                layoutManager.setNeedsLayout()
                setNeedsLayout()
                layoutIfNeeded()
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
                layoutManager.invalidateLines()
                layoutManager.setNeedsLayout()
                setNeedsLayout()
                layoutIfNeeded()
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
                layoutIfNeeded()
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
                layoutIfNeeded()
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
                layoutIfNeeded()
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
                layoutIfNeeded()
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
                layoutIfNeeded()
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
                // Notify the delegate that the selection may changeas the position
                // of the caret will change when we adjust the height of lines.
                inputDelegate?.selectionWillChange(self)
                layoutManager.lineHeightMultiplier = newValue
                lineManager.estimatedLineHeight = estimatedLineHeight
                layoutManager.setNeedsLayout()
                inputDelegate?.selectionDidChange(self)
                // Do a layout pass to ensure the position of the caret is correct.
                setNeedsLayout()
                layoutIfNeeded()
            }
        }
    }
    var characterPairs: [CharacterPair] = []
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
                layoutIfNeeded()
            }
        }
    }
    private var estimatedLineHeight: CGFloat {
        return theme.font.lineHeight * lineHeightMultiplier
    }

    // MARK: - Contents
    weak var delegate: TextInputViewDelegate?
    var string: NSMutableString {
        get {
            return stringView.string
        }
        set {
            if newValue != stringView.string {
                stringView.string = newValue
                languageMode.parse(newValue as String)
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
    private(set) var lineManager: LineManager {
        didSet {
            if lineManager !== oldValue {
                indentController.lineManager = lineManager
                lineMovementController.lineManager = lineManager
            }
        }
    }

    // MARK: - Private
    private var stringView = StringView() {
        didSet {
            if stringView !== oldValue {
                lineManager.stringView = stringView
                layoutManager.stringView = stringView
                indentController.stringView = stringView
                lineMovementController.stringView = stringView
            }
        }
    }
    private var languageMode: LanguageMode = PlainTextLanguageMode() {
        didSet {
            if languageMode !== oldValue {
                indentController.languageMode = languageMode
                if let treeSitterLanguageMode = languageMode as? TreeSitterLanguageMode {
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
    private var parsedLine: ParsedLine?
    private var floatingCaretView: FloatingCaretView?
    private var insertionPointColorBeforeFloatingBegan: UIColor = .black
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

    func setState(_ state: TextViewState) {
        stringView = state.stringView
        theme = state.theme
        languageMode = state.languageMode
        lineManager = state.lineManager
        lineManager.estimatedLineHeight = estimatedLineHeight
        layoutManager.languageMode = state.languageMode
        layoutManager.lineManager = state.lineManager
        layoutManager.invalidateContentSize()
        layoutManager.updateLineNumberWidth()
    }

    func moveCaret(to point: CGPoint) {
        if let index = layoutManager.closestIndex(to: point) {
            selectedTextRange = IndexedRange(location: index, length: 0)
        }
    }

    func setLanguage(_ language: TreeSitterLanguage?, completion: ((Bool) -> Void)? = nil) {
        let newLanguageMode: LanguageMode
        if let language = language {
            newLanguageMode = TreeSitterLanguageMode(language: language, stringView: stringView, lineManager: lineManager)
        } else {
            newLanguageMode = PlainTextLanguageMode()
        }
        self.languageMode = newLanguageMode
        layoutManager.languageMode = newLanguageMode
        newLanguageMode.parse(string as String) { [weak self] finished in
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
            let pageGuideXPosition = layoutManager.gutterWidth + textContainerInset.left + pageGuideController.columnOffset
            let pageGuideOrigin = CGPoint(x: pageGuideXPosition, y: viewport.minY)
            let pageGuideSize = CGSize(width: bounds.width - pageGuideXPosition + widthExtension, height: viewport.height)
            if pageGuideSize.width > 0 {
                pageGuideController.guideView.frame = CGRect(origin: pageGuideOrigin, size: pageGuideSize)
            } else {
                pageGuideController.guideView.frame = .zero
            }
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
            if text == Symbol.lineFeed {
                inputDelegate?.selectionWillChange(self)
                indentController.insertLineBreak(in: selectedRange)
                layoutIfNeeded()
                inputDelegate?.selectionDidChange(self)
                delegate?.textInputViewDidChangeSelection(self)
            } else {
                inputDelegate?.selectionWillChange(self)
                justInsert(text, in: selectedRange)
                inputDelegate?.selectionDidChange(self)
                delegate?.textInputViewDidChangeSelection(self)
            }
        }
    }

    private func justInsert(_ text: String, in range: NSRange) {
        let nsText = text as NSString
        let currentText = self.text(in: range) ?? ""
        let newRange = NSRange(location: range.location, length: nsText.length)
        addUndoOperation(replacing: newRange, withText: currentText)
        selectedRange = NSRange(location: newRange.upperBound, length: 0)
        replaceCharacters(in: range, with: nsText)
    }

    func deleteBackward() {
        guard let selectedRange = selectedRange, selectedRange.length > 0 else {
            return
        }
        let deleteRange: NSRange
        if selectedRange.length == 1, let indentRange = indentController.indentRangeInfrontOfLocation(selectedRange.upperBound) {
            deleteRange = indentRange
        } else {
            deleteRange = selectedRange
        }
        if shouldChangeText(in: deleteRange, replacementText: "") {
            if let currentText = text(in: deleteRange) {
                let undoRange = NSRange(location: deleteRange.location, length: 0)
                addUndoOperation(replacing: undoRange, withText: currentText)
            }
            inputDelegate?.selectionWillChange(self)
            self.selectedRange = NSRange(location: deleteRange.location, length: 0)
            replaceCharacters(in: deleteRange, with: "")
            inputDelegate?.selectionDidChange(self)
            delegate?.textInputViewDidChangeSelection(self)
        }
    }

    func replace(_ range: UITextRange, withText text: String) {
        if let indexedRange = range as? IndexedRange, shouldChangeText(in: indexedRange.range, replacementText: text) {
            inputDelegate?.selectionWillChange(self)
            justInsert(text, in: indexedRange.range)
            layoutIfNeeded()
            inputDelegate?.selectionDidChange(self)
            delegate?.textInputViewDidChangeSelection(self)
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
        if range.location >= 0 && range.location + range.length <= string.length {
            return string.substring(with: range)
        } else {
            return nil
        }
    }

    private func replaceCharacters(in range: NSRange, with newString: NSString) {
        let changeSet = justReplaceCharacters(in: range, with: newString)
        let didAddOrRemoveLines = !changeSet.insertedLines.isEmpty || !changeSet.removedLines.isEmpty
        if didAddOrRemoveLines {
            layoutManager.invalidateContentSize()
            for removedLine in changeSet.removedLines {
                layoutManager.removeLine(withID: removedLine.id)
            }
            layoutManager.updateLineNumberWidth()
        }
        layoutManager.typeset(changeSet.editedLines)
        layoutManager.syntaxHighlight(changeSet.editedLines)
        layoutManager.setNeedsLayout()
        delegate?.textInputViewDidChange(self)
        if didAddOrRemoveLines {
            delegate?.textInputViewDidInvalidateContentSize(self)
        }
    }

    private func justReplaceCharacters(in range: NSRange, with nsNewString: NSString) -> LineChangeSet {
        let byteRange = self.byteRange(from: range)
        let newString = nsNewString as String
        let oldEndLinePosition = lineManager.linePosition(at: range.location + range.length)!
        string.replaceCharacters(in: range, with: newString)
        let changeSet = LineChangeSet()
        let newChangeSetA = lineManager.removeCharacters(in: range)
        changeSet.union(with: newChangeSetA)
        let newChangeSetB = lineManager.insert(nsNewString, at: range.location)
        changeSet.union(with: newChangeSetB)
        let startLinePosition = lineManager.linePosition(at: range.location)!
        let newEndLinePosition = lineManager.linePosition(at: range.location + nsNewString.length)!
        let textChange = LanguageModeTextChange(
            byteRange: byteRange,
            newString: newString,
            oldEndLinePosition: oldEndLinePosition,
            startLinePosition: startLinePosition,
            newEndLinePosition: newEndLinePosition)
        let result = languageMode.textDidChange(textChange)
        let languageModeEditedLines = result.changedRows.map { lineManager.line(atRow: $0) }
        for editedLine in languageModeEditedLines {
            changeSet.markLineEdited(editedLine)
        }
        return changeSet
    }

    private func byteRange(from range: NSRange) -> ByteRange {
        if range.length == 0 {
            let byteOffset = byteOffsetForCharacter(at: range.location)
            return ByteRange(location: byteOffset, length: ByteCount(0))
        } else {
            let startByteOffset = byteOffsetForCharacter(at: range.location)
            let endByteOffset = byteOffsetForCharacter(at: range.location + range.length)
            return ByteRange(from: startByteOffset, to: endByteOffset)
        }
    }

    private func byteOffsetForCharacter(at location: Int) -> ByteCount {
        let line = lineManager.line(containingCharacterAt: location)!
        let lineGlobalRange = NSRange(location: line.location, length: line.value)
        let lineLocalLocation = location - lineGlobalRange.location
        let lineString = string.substring(with: lineGlobalRange)
        let localByteOffset = lineString.byteOffset(at: lineLocalLocation)
        return line.data.startByte + localByteOffset
    }

    private func shouldChangeText(in range: NSRange, replacementText text: String) -> Bool {
        return delegate?.textInputView(self, shouldChangeTextIn: range, replacementText: text) ?? true
    }

    private func addUndoOperation(replacing range: NSRange, withText text: String) {
        timedUndoManager.beginUndoGrouping()
        timedUndoManager.setActionName(L10n.Undo.ActionName.typing)
        timedUndoManager.registerUndo(withTarget: self) { textInputView in
            let indexedRange = IndexedRange(range: range)
            textInputView.justInsert(text, in: indexedRange.range)
            let textLength = text.utf16.count
            if range.length > 0 && textLength > 0 {
                self.selectedRange = NSRange(location: range.location, length: textLength)
            }
            self.inputDelegate?.selectionWillChange(self)
            self.layoutIfNeeded()
            self.inputDelegate?.selectionDidChange(self)
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
}

// MARK: - Indent and Outdent
extension TextInputView {
    func shiftLeft() {
        if let selectedRange = selectedRange {
            indentController.shiftLeft(in: selectedRange)
        }
    }

    func shiftRight() {
        if let selectedRange = selectedRange {
            indentController.shiftRight(in: selectedRange)
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
        return IndexedRange(range: range)
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
    func treeSitterLanguageMode(_ languageMode: TreeSitterLanguageMode, bytesAt byteIndex: ByteCount) -> [Int8]? {
        // Speed up parsing by using the line we recently parsed bytes in when possible.
        if let parsedLine = parsedLine, byteIndex >= parsedLine.startByte && byteIndex < parsedLine.endByte {
            return bytes(at: byteIndex, in: parsedLine)
        } else if let line = lineManager.line(containingByteAt: byteIndex) {
            let startByte = line.data.startByte
            let lineRange = NSRange(location: line.location, length: line.data.totalLength)
            let lineString = string.substring(with: lineRange)
            let parsedLine = ParsedLine(startByte: startByte, byteCount: line.data.byteCount, lineRange: lineRange, lineString: lineString)
            self.parsedLine = parsedLine
            return bytes(at: byteIndex, in: parsedLine)
        } else {
            parsedLine = nil
            return nil
        }
    }

    private func bytes(at byteIndex: ByteCount, in parsedLine: ParsedLine) -> [Int8]? {
        let lineString = parsedLine.lineString
        let localByteIndex = byteIndex - parsedLine.startByte
        let localLocation = lineString.location(from: localByteIndex)
        let globalLocation = parsedLine.lineRange.location + localLocation
        guard globalLocation < string.length else {
            return nil
        }
        let range = string.rangeOfComposedCharacterSequence(at: globalLocation)
        let substring = string.substring(with: range)
        return substring.cString(using: .utf8)?.dropLast()
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
        // Typeset lines again when the line number width changes. Changing line number width may increase
        // or reduce the number of line fragments in a line.
        layoutManager.invalidateLines()
        layoutManager.setNeedsLayout()
        layoutManager.layoutIfNeeded()
        delegate?.textInputViewDidUpdateGutterWidth(self)
    }

    func layoutManagerDidInvalidateLineWidthDuringAsyncSyntaxHighlight(_ layoutManager: LayoutManager) {
        // Sizing may be invalidated when doing async syntax highlighting, in which case we need to do another layout pass.
        layoutManager.setNeedsLayout()
        layoutManager.layoutIfNeeded()
    }
}

// MARK: - IndentControllerDelegate
extension TextInputView: IndentControllerDelegate {
    func indentController(_ controller: IndentController, shouldInsert text: String, in range: NSRange) {
        justInsert(text, in: range)
    }

    func indentController(_ controller: IndentController, shouldSelect range: NSRange) {
        if range != selectedRange {
            selectedTextRange = IndexedRange(range: range)
        }
    }
}

// MARK: - LineMovementControllerDelegate
extension TextInputView: LineMovementControllerDelegate {
    func lineMovementController(_ controller: LineMovementController, numberOfLineFragmentsIn line: DocumentLineNode) -> Int {
        return layoutManager.numberOfLineFragments(in: line)
    }

    func lineMovementController(_ controller: LineMovementController, lineFragmentNodeAtIndex index: Int, in line: DocumentLineNode) -> LineFragmentNode {
        return layoutManager.lineFragmentNode(atIndex: index, in: line)
    }

    func lineMovementController(_ controller: LineMovementController, lineFragmentNodeContainingCharacterAt location: Int, in line: DocumentLineNode) -> LineFragmentNode {
        return layoutManager.lineFragmentNode(containingCharacterAt: location, in: line)
    }
}
