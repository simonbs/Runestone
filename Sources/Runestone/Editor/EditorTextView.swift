//
//  EditorTextView.swift
//  
//
//  Created by Simon Støvring on 04/01/2021.
//

import CoreText
import UIKit

public protocol EditorTextViewDelegate: AnyObject {
    func editorTextViewShouldBeginEditing(_ textView: EditorTextView) -> Bool
    func editorTextViewShouldEndEditing(_ textView: EditorTextView) -> Bool
    func editorTextViewDidBeginEditing(_ textView: EditorTextView)
    func editorTextViewDidEndEditing(_ textView: EditorTextView)
    func editorTextViewDidChange(_ textView: EditorTextView)
    func editorTextViewDidChangeSelection(_ textView: EditorTextView)
    func editorTextView(_ textView: EditorTextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
    func editorTextView(_ textView: EditorTextView, shouldInsert characterPair: EditorCharacterPair, in range: NSRange) -> Bool
    func editorTextView(_ textView: EditorTextView, shouldSkipTrailingComponentOf characterPair: EditorCharacterPair, in range: NSRange) -> Bool
    func editorTextViewDidUpdateGutterWidth(_ textView: EditorTextView)
}

public extension EditorTextViewDelegate {
    func editorTextViewShouldBeginEditing(_ textView: EditorTextView) -> Bool {
        return true
    }
    func editorTextViewShouldEndEditing(_ textView: EditorTextView) -> Bool {
        return true
    }
    func editorTextViewDidBeginEditing(_ textView: EditorTextView) {}
    func editorTextViewDidEndEditing(_ textView: EditorTextView) {}
    func editorTextViewDidChange(_ textView: EditorTextView) {}
    func editorTextViewDidChangeSelection(_ textView: EditorTextView) {}
    func editorTextView(_ textView: EditorTextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        return true
    }
    func editorTextView(_ textView: EditorTextView, shouldInsert characterPair: EditorCharacterPair, in range: NSRange) -> Bool {
        return true
    }
    func editorTextView(_ textView: EditorTextView, shouldSkipTrailingComponentOf characterPair: EditorCharacterPair, in range: NSRange) -> Bool {
        return true
    }
    func editorTextViewDidUpdateGutterWidth(_ textView: EditorTextView) {}
}

public final class EditorTextView: UIScrollView {
    /// Delegate to receive callbacks for events triggered by the editor.
    public weak var editorDelegate: EditorTextViewDelegate?
    /// Whether the text view is in a state where the contents can be edited.
    public private(set) var isEditing = false {
        didSet {
            if isEditing != oldValue {
                textInputView.isEditing = isEditing
            }
        }
    }
    public var text: String {
        get {
            return textInputView.string as String
        }
        set {
            textInputView.string = NSMutableString(string: newValue)
            contentSize = textInputView.contentSize
        }
    }
    /// Colors and fonts to be used by the editor.
    public var theme: EditorTheme {
        get {
            return textInputView.theme
        }
        set {
            textInputView.theme = newValue
        }
    }
    public var autocorrectionType: UITextAutocorrectionType {
        get {
            return textInputView.autocorrectionType
        }
        set {
            textInputView.autocorrectionType = newValue
        }
    }
    public var autocapitalizationType: UITextAutocapitalizationType {
        get {
            return textInputView.autocapitalizationType
        }
        set {
            textInputView.autocapitalizationType = newValue
        }
    }
    public var smartQuotesType: UITextSmartQuotesType {
        get {
            return textInputView.smartQuotesType
        }
        set {
            textInputView.smartQuotesType = newValue
        }
    }
    public var smartDashesType: UITextSmartDashesType {
        get {
            return textInputView.smartDashesType
        }
        set {
            textInputView.smartDashesType = newValue
        }
    }
    public var smartInsertDeleteType: UITextSmartInsertDeleteType {
        get {
            return textInputView.smartInsertDeleteType
        }
        set {
            textInputView.smartInsertDeleteType = newValue
        }
    }
    public var spellCheckingType: UITextSpellCheckingType {
        get {
            return textInputView.spellCheckingType
        }
        set {
            textInputView.spellCheckingType = newValue
        }
    }
    public var keyboardType: UIKeyboardType {
        get {
            return textInputView.keyboardType
        }
        set {
            textInputView.keyboardType = newValue
        }
    }
    public var keyboardAppearance: UIKeyboardAppearance {
        get {
            return textInputView.keyboardAppearance
        }
        set {
            textInputView.keyboardAppearance = newValue
        }
    }
    public var returnKeyType: UIReturnKeyType {
        get {
            return textInputView.returnKeyType
        }
        set {
            textInputView.returnKeyType = newValue
        }
    }
    public override var undoManager: UndoManager? {
        return textInputView.undoManager
    }
    /// The color of the insertion point. This can be used to control the color of the caret.
    public var insertionPointColor: UIColor {
        get {
            return textInputView.insertionPointColor
        }
        set {
            textInputView.insertionPointColor = newValue
        }
    }
    /// The color of the selection bar. It is most common to set this to the same color as the color used for the insertion point.
    public var selectionBarColor: UIColor {
        get {
            return textInputView.selectionBarColor
        }
        set {
            textInputView.selectionBarColor = newValue
        }
    }
    /// The color of the selection highlight. It is most common to set this to the same color as the color used for the insertion point.
    public var selectionHighlightColor: UIColor {
        get {
            return textInputView.selectionHighlightColor
        }
        set {
            textInputView.selectionHighlightColor = newValue
        }
    }
    public var selectedRange: NSRange {
        if let selectedRange = textInputView.selectedRange {
            return selectedRange
        } else {
            // UITextView returns the end of the document for the selectedRange by default.
            return NSRange(location: textInputView.string.length, length: 0)
        }
    }
    public var selectedTextRange: UITextRange? {
        return IndexedRange(range: selectedRange)
    }
    public override var inputAccessoryView: UIView? {
        get {
            return _inputAccessoryView
        }
        set {
            _inputAccessoryView = newValue
        }
    }
    public override var canBecomeFirstResponder: Bool {
        return !textInputView.isFirstResponder
    }
    public override var backgroundColor: UIColor? {
        get {
            return textInputView.backgroundColor
        }
        set {
            super.backgroundColor = newValue
            textInputView.backgroundColor = newValue
        }
    }
    public override var contentOffset: CGPoint {
        didSet {
            if contentOffset != oldValue {
                textInputView.viewport = CGRect(origin: contentOffset, size: frame.size)
            }
        }
    }
    /// Character pairs are used by the editor to automatically insert a trailing character when the user types the leading character. Common usages of this includes the \" character to surround strings and { } to surround a scope.
    public var characterPairs: [EditorCharacterPair] {
        get {
            return textInputView.characterPairs
        }
        set {
            textInputView.characterPairs = newValue
        }
    }
    /// Enable to show line numbers in the gutter.
    public var showLineNumbers: Bool {
        get {
            return textInputView.showLineNumbers
        }
        set {
            textInputView.showLineNumbers = newValue
        }
    }
    /// Enable to show highlight the selected lines. The selection is only shown in the gutter when multiple lines are selected.
    public var showSelectedLines: Bool {
        get {
            return textInputView.showSelectedLines
        }
        set {
            textInputView.showSelectedLines = newValue
        }
    }
    /// The text view renders invisible tabs when enabled. The `tabsSymbol` is used to render tabs.
    public var showTabs: Bool {
        get {
            return textInputView.showTabs
        }
        set {
            textInputView.showTabs = newValue
        }
    }
    /// The text view renders invisible spaces when enabled. The `spaceSymbol` is used to render spaces.
    public var showSpaces: Bool {
        get {
            return textInputView.showSpaces
        }
        set {
            textInputView.showSpaces = newValue
        }
    }
    /// The text view renders invisible line breaks when enabled. The `lineBreakSymbol` is used to render line breaks.
    public var showLineBreaks: Bool {
        get {
            return textInputView.showLineBreaks
        }
        set {
            textInputView.showLineBreaks = newValue
        }
    }
    /// Used when rendering tabs. The value is only used when invisible tab characters is enabled. The default is ▸.
    public var tabSymbol: String {
        get {
            return textInputView.tabSymbol
        }
        set {
            textInputView.tabSymbol = newValue
        }
    }
    /// Used when rendering spaces. The value is only used when showing invisible space characters is enabled. The default is ·.
    public var spaceSymbol: String {
        get {
            return textInputView.spaceSymbol
        }
        set {
            textInputView.spaceSymbol = newValue
        }
    }
    /// Used when rendering line breaks. The value is only used when showing invisible line break characters is enabled. The default is ¬.
    public var lineBreakSymbol: String {
        get {
            return textInputView.lineBreakSymbol
        }
        set {
            textInputView.lineBreakSymbol = newValue
        }
    }
    /// The behavior used when indenting text.
    public var indentBehavior: EditorIndentBehavior {
        get {
            return textInputView.indentBehavior
        }
        set {
            textInputView.indentBehavior = newValue
        }
    }
    /// The amount of padding before the line numbers inside the gutter.
    public var gutterLeadingPadding: CGFloat {
        get {
            return textInputView.gutterLeadingPadding
        }
        set {
            textInputView.gutterLeadingPadding = newValue
        }
    }
    /// The amount of padding after the line numbers inside the gutter.
    public var gutterTrailingPadding: CGFloat {
        get {
            return textInputView.gutterTrailingPadding
        }
        set {
            textInputView.gutterTrailingPadding = newValue
        }
    }
    // The amount of spacing surrounding the lines.
    public var textContainerInset: UIEdgeInsets {
        get {
            return textInputView.textContainerInset
        }
        set {
            textInputView.textContainerInset = newValue
        }
    }
    /// When line wrapping is disabled, users can scroll the text view horizontally to see the entire line.
    /// Line wrapping is enabled by default.
    public var isLineWrappingEnabled: Bool {
        get {
            return textInputView.isLineWrappingEnabled
        }
        set {
            textInputView.isLineWrappingEnabled = newValue
        }
    }
    /// Width of the gutter.
    public var gutterWidth: CGFloat {
        return textInputView.gutterWidth
    }
    /// The line height is multiplied with the value.
    public var lineHeightMultiplier: CGFloat {
        get {
            return textInputView.lineHeightMultiplier
        }
        set {
            textInputView.lineHeightMultiplier = newValue
        }
    }

    private let textInputView = TextInputView()
    private let editingTextInteraction = UITextInteraction(for: .editable)
    private let tapGestureRecognizer = UITapGestureRecognizer()
    private var _inputAccessoryView: UIView?
    private var shouldBeginEditing: Bool {
        if let editorDelegate = editorDelegate {
            return editorDelegate.editorTextViewShouldBeginEditing(self)
        } else {
            return true
        }
    }
    private var shouldEndEditing: Bool {
        if let editorDelegate = editorDelegate {
            return editorDelegate.editorTextViewShouldEndEditing(self)
        } else {
            return true
        }
    }
    private var hasPendingContentSizeUpdate = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        textInputView.delegate = self
        textInputView.editorView = self
        editingTextInteraction.textInput = textInputView
        addSubview(textInputView)
        tapGestureRecognizer.delegate = self
        tapGestureRecognizer.addTarget(self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGestureRecognizer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        handleContentSizeUpdateIfNecessary()
        textInputView.scrollViewWidth = frame.width
        textInputView.frame = CGRect(x: 0, y: 0, width: max(contentSize.width, frame.width), height: max(contentSize.height, frame.height))
        textInputView.viewport = CGRect(origin: contentOffset, size: frame.size)
        bringSubviewToFront(textInputView.gutterContainerView)
    }

    public override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        contentSize = textInputView.contentSize
    }

    @discardableResult
    public override func becomeFirstResponder() -> Bool {
        if !textInputView.isFirstResponder && shouldBeginEditing && textInputView.becomeFirstResponder()  {
            isEditing = true
            addInteraction(editingTextInteraction)
            editorDelegate?.editorTextViewDidBeginEditing(self)
            return true
        } else {
            return false
        }
    }

    @discardableResult
    public override func resignFirstResponder() -> Bool {
        if shouldEndEditing {
            isEditing = false
            removeInteraction(editingTextInteraction)
            editorDelegate?.editorTextViewDidEndEditing(self)
            return textInputView.resignFirstResponder()
        } else {
            return false
        }
    }

    /// Sets the current _state_ of the editor. The state contains the text to be displayed by the editor and
    /// various additional information about the text that the editor needs to show the text.
    ///
    /// It is safe to create an instance of <code>EditorState</code> in the background, and as such it can be
    /// created before presenting the editor to the user, e.g. when opening the document from an instance of
    /// <code>UIDocumentBrowserViewController</code>.
    ///
    /// This is the preferred way to initially set the text, language and theme on the <code>EditorTextView</code>.
    /// - Parameter state: The new state to be used by the editor.
    public func setState(_ state: EditorState) {
        textInputView.setState(state)
        contentSize = textInputView.contentSize
    }

    /// The line position at a location in the text. Common usages of this includes showing the line and column\
    /// that the caret is currently located at.
    /// - Parameter location: The location is relative to the first index in the string.
    /// - Returns: The line position if the location could be found in the string, otherwise nil.
    public func linePosition(at location: Int) -> LinePosition? {
        return textInputView.linePosition(at: location)
    }

    /// Sets the language on a background thread.
    ///
    /// - Parameters:
    ///   - language: The new language to be used by the editor.
    ///   - completion: Called when the content have been parsed or when parsing fails.
    public func setLanguage(_ language: TreeSitterLanguage?, completion: ((Bool) -> Void)? = nil) {
        textInputView.setLanguage(language, completion: completion)
    }

    /// Insets text at the location of the caret.
    /// - Parameter text: A text to insert.
    public func insertText(_ text: String) {
        textInputView.insertText(text)
    }

    /// Replaces the text that is in the specified range.
    /// - Parameters:
    ///   - range: A range of text in the document.
    ///   - text: A string to replace the text in range.
    public func replace(_ range: UITextRange, withText text: String) {
        textInputView.replace(range, withText: text)
    }

    /// Returns the text in the specified range.
    /// - Parameter range: A range of text in the document.
    /// - Returns: The substring that falls within the specified range.
    public func text(in range: NSRange) -> String? {
        return textInputView.text(in: range)
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
        return textInputView.syntaxNode(at: location)
    }

    /// Checks if the specified locations is within the indentation of the line.
    ///
    /// - Parameter location: A location in the document.
    /// - Returns: True if the location is within the indentation of the line, otherwise false.
    public func isIndentation(at location: Int) -> Bool {
        return textInputView.isIndentation(at: location)
    }

    /// Decreases the indentation level of the selected lines.
    public func shiftLeft() {
        textInputView.shiftLeft()
    }

    /// Increases the indentation level of the selected lines.
    public func shiftRight() {
        textInputView.shiftRight()
    }
}

private extension EditorTextView {
    @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        if tapGestureRecognizer.state == .ended {
            let point = gestureRecognizer.location(in: textInputView)
            becomeFirstResponder()
            textInputView.moveCaret(to: point)
        }
    }

    private func scrollToCaret() {
        if let textPosition = textInputView.selectedTextRange?.end {
            scroll(to: textPosition)
        }
    }

    private func scroll(to textPosition: UITextPosition) {
        let gutterWidth = textInputView.gutterWidth
        let caretRect = textInputView.caretRect(for: textPosition)
        var newXOffset = contentOffset.x
        var newYOffset = contentOffset.y
        var visibleBounds = bounds
        visibleBounds.origin.y += adjustedContentInset.top
        visibleBounds.size.height -= adjustedContentInset.top + adjustedContentInset.bottom
        if caretRect.minX - gutterWidth < visibleBounds.minX {
            newXOffset = caretRect.minX - gutterWidth
        } else if caretRect.maxX > visibleBounds.maxX {
            newXOffset = caretRect.maxX - frame.width
        }
        if caretRect.minY < visibleBounds.minY {
            newYOffset = caretRect.minY - adjustedContentInset.top
        } else if caretRect.maxY > visibleBounds.maxY {
            newYOffset = caretRect.maxY - visibleBounds.height - adjustedContentInset.top
        }
        let newContentOffset = CGPoint(x: newXOffset, y: newYOffset)
        if newContentOffset != contentOffset {
            contentOffset = newContentOffset
        }
    }

    private func insertLeadingComponent(of characterPair: EditorCharacterPair, in range: NSRange) -> Bool {
        let shouldInsertCharacterPair = editorDelegate?.editorTextView(self, shouldInsert: characterPair, in: range) ?? true
        guard shouldInsertCharacterPair else {
            return false
        }
        guard let selectedRange = textInputView.selectedRange else {
            return false
        }
        if selectedRange.length == 0 {
            textInputView.insertText(characterPair.leading + characterPair.trailing)
            let newSelectedRange = NSRange(location: range.location + characterPair.leading.count, length: 0)
            textInputView.selectedTextRange = IndexedRange(range: newSelectedRange)
            return true
        } else if let text = textInputView.text(in: selectedRange) {
            let modifiedText = characterPair.leading + text + characterPair.trailing
            let indexedRange = IndexedRange(range: selectedRange)
            textInputView.replace(indexedRange, withText: modifiedText)
            let newSelectedRange = NSRange(location: range.location + characterPair.leading.count, length: range.length)
            textInputView.selectedTextRange = IndexedRange(range: newSelectedRange)
            return true
        } else {
            return false
        }
    }

    private func skipInsertingTrailingComponent(of characterPair: EditorCharacterPair, in range: NSRange) -> Bool {
        // If the user is typing the trailing component of a character pair, e.g. ) or } and the cursor is just in front
        // of that character, then we give the delegate the option to skip inserting the character. In that case we
        // move the caret to after the character in front of it instead.
        let followingTextRange = NSRange(location: range.location + range.length, length: characterPair.trailing.count)
        let followingText = textInputView.text(in: followingTextRange)
        guard followingText == characterPair.trailing else {
            return false
        }
        let shouldSkip = editorDelegate?.editorTextView(self, shouldSkipTrailingComponentOf: characterPair, in: range) ?? true
        if shouldSkip {
            moveCaret(byOffset: characterPair.trailing.count)
            return true
        } else {
            return editorDelegate?.editorTextView(self, shouldChangeTextIn: range, replacementText: text) ?? true
        }
    }

    private func moveCaret(byOffset offset: Int) {
        if let selectedRange = textInputView.selectedRange {
            let newSelectedRange = NSRange(location: selectedRange.location + offset, length: 0)
            textInputView.selectedTextRange = IndexedRange(range: newSelectedRange)
        }
    }

    private func handleContentSizeUpdateIfNecessary() {
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
                contentSize = textInputView.contentSize
                setNeedsLayout()
            }
        }
    }
}

// MARK: - TextInputViewDelegate
extension EditorTextView: TextInputViewDelegate {
    func textInputViewDidChange(_ view: TextInputView) {
        editorDelegate?.editorTextViewDidChange(self)
    }

    func textInputViewDidChangeSelection(_ view: TextInputView) {
        scrollToCaret()
        editorDelegate?.editorTextViewDidChangeSelection(self)
    }

    func textInputViewDidInvalidateContentSize(_ view: TextInputView) {
        if contentSize != view.contentSize {
            hasPendingContentSizeUpdate = true
            handleContentSizeUpdateIfNecessary()
        }
    }

    func textInputView(_ view: TextInputView, didProposeContentOffsetAdjustment contentOffsetAdjustment: CGPoint) {
        let isScrolling = isDragging || isDecelerating
        if contentOffsetAdjustment != .zero && isScrolling {
            contentOffset = CGPoint(x: contentOffset.x + contentOffsetAdjustment.x, y: contentOffset.y + contentOffsetAdjustment.y)
        }
    }

    func textInputView(_ view: TextInputView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if let characterPair = characterPairs.first(where: { $0.trailing == text }), skipInsertingTrailingComponent(of: characterPair, in: range) {
            return false
        } else if let characterPair = characterPairs.first(where: { $0.leading == text }), insertLeadingComponent(of: characterPair, in: range) {
            return false
        } else {
            return editorDelegate?.editorTextView(self, shouldChangeTextIn: range, replacementText: text) ?? true
        }
    }

    func textInputViewDidUpdateGutterWidth(_ view: TextInputView) {
        editorDelegate?.editorTextViewDidUpdateGutterWidth(self)
    }
}

// MARK: - UIGestureRecognizerDelegate
extension EditorTextView: UIGestureRecognizerDelegate {
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === tapGestureRecognizer {
            return shouldBeginEditing && !isFirstResponder && !textInputView.isFirstResponder
        } else {
            return true
        }
    }
}
