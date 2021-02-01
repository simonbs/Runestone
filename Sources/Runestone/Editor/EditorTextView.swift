//
//  EditorTextView.swift
//  
//
//  Created by Simon Støvring on 04/01/2021.
//

import UIKit
import CoreText

public protocol EditorTextViewDelegate: AnyObject {
    func editorTextViewShouldBeginEditing(_ textView: EditorTextView) -> Bool
    func editorTextViewShouldEndEditing(_ textView: EditorTextView) -> Bool
    func editorTextViewDidBeginEditing(_ textView: EditorTextView)
    func editorTextViewDidEndEditing(_ textView: EditorTextView)
    func editorTextViewDidChange(_ textView: EditorTextView)
    func editorTextViewDidChangeSelection(_ textView: EditorTextView)
    func editorTextView(_ textView: EditorTextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
    func editorTextView(_ textView: EditorTextView, shouldInsert characterPair: EditorCharacterPair, in range: NSRange) -> Bool
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
}

public final class EditorTextView: UIScrollView {
    /// Delegate to receive callbacks for events triggered by the editor.
    public weak var editorDelegate: EditorTextViewDelegate?
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
    /// Languages to for syntax highlighting the text in the editor. Setting the language will cause
    /// the parser to immediately parse the entire document. Consider using `setLanguage(:completion:)`
    /// to parse the language on a background thread.
    public var language: Language? {
        get {
            return textInputView.language
        }
        set {
            textInputView.language = newValue
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
    public var selectedTextRange: NSRange? {
        return textInputView.selectedRange
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
        return true
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
    public var characterPairs: [EditorCharacterPair] = []
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
    // The amount of spacing between the gutter and the lines. The value is only used when line numbers are enabled.
    public var gutterMargin: CGFloat {
        get {
            return textInputView.gutterMargin
        }
        set {
            textInputView.gutterMargin = newValue
        }
    }
    /// The amount of spacing after a line. The value is only used when line wrapping is disabled.
    public var lineMargin: CGFloat {
        get {
            return textInputView.lineMargin
        }
        set {
            textInputView.lineMargin = newValue
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

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        textInputView.delegate = self
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
        textInputView.frame = CGRect(x: 0, y: 0, width: frame.width, height: contentSize.height)
        textInputView.viewport = CGRect(origin: contentOffset, size: frame.size)
    }

    @discardableResult
    public override func becomeFirstResponder() -> Bool {
        if shouldBeginEditing {
            return textInputView.becomeFirstResponder()
        } else {
            return false
        }
    }

    @discardableResult
    public override func resignFirstResponder() -> Bool {
        if shouldEndEditing {
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

    /// Sets the language used to highlight the content of the editor on a background thread.
    /// This should generally be preferred over using the <code>language</code> setter.
    ///
    /// - Parameters:
    ///   - language: The new language to be used by the parser.
    ///   - completion: Called when the content have been parsed or when parsing fails.
    public func setLanguage(_ language: Language?, completion: ((Bool) -> Void)? = nil) {
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
    public func replace(_ range: NSRange, withText text: String) {
        textInputView.replace(range, withText: text)
    }

    /// Deletes the character before the caret.
    public func deleteBackward() {
        textInputView.deleteBackward()
    }

    /// Returns the text in the specified range.
    /// - Parameter range: A range of text in the document.
    /// - Returns: The substring that falls within the specified range.
    public func text(in range: NSRange) -> String? {
        return textInputView.text(in: range)
    }

    /// Returns the node at the specified location in the document. This provides information about the type
    /// of token at the location, e.g. if it's a string, a number, a keyword etc.
    ///
    /// This can be used with character pairs to determine if a pair should be inserted or not.
    /// For example, a character pair consisting of two quotes (") to surround a string, should probably not be
    /// inserted when the quote is typed while the caret is already inside a string.
    ///
    /// This requires a language to be set on the editor.
    /// - Parameter location: A location in the document.
    /// - Returns: The node at the location.
    public func node(at location: Int) -> Node? {
        return textInputView.node(at: location)
    }
}

// MARK: - Interaction
private extension EditorTextView {
    @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        if tapGestureRecognizer.state == .ended {
            let point = gestureRecognizer.location(in: textInputView)
            textInputView.moveCaret(to: point)
            textInputView.becomeFirstResponder()
        }
    }
}

// MARK: - Editing
private extension EditorTextView {
    private func insert(_ characterPair: EditorCharacterPair, in range: NSRange) {
        guard let selectedRange = textInputView.selectedRange else {
            return
        }
        if selectedRange.length == 0 {
            textInputView.insertText(characterPair.leading + characterPair.trailing)
            let newSelectedRange = NSRange(location: range.location + characterPair.leading.count, length: 0)
            textInputView.selectedTextRange = IndexedRange(range: newSelectedRange)
        } else if let text = textInputView.text(in: selectedRange) {
            let modifiedText = characterPair.leading + text + characterPair.trailing
            textInputView.replace(selectedRange, withText: modifiedText)
            let newSelectedRange = NSRange(location: range.location + characterPair.leading.count, length: range.length)
            textInputView.selectedTextRange = IndexedRange(range: newSelectedRange)
        }
    }
}

// MARK: - TextInputViewDelegate
extension EditorTextView: TextInputViewDelegate {
    func textInputViewDidBeginEditing(_ view: TextInputView) {
        addInteraction(editingTextInteraction)
        editorDelegate?.editorTextViewDidBeginEditing(self)
    }

    func textInputViewDidEndEditing(_ view: TextInputView) {
        removeInteraction(editingTextInteraction)
        editorDelegate?.editorTextViewDidEndEditing(self)
    }

    func textInputViewDidChange(_ view: TextInputView) {
        editorDelegate?.editorTextViewDidChange(self)
    }

    func textInputViewDidChangeSelection(_ view: TextInputView) {
        editorDelegate?.editorTextViewDidChangeSelection(self)
    }

    func textInputViewDidInvalidateContentSize(_ view: TextInputView) {
        if contentSize != view.contentSize {
            contentSize = view.contentSize
            setNeedsLayout()
        }
    }

    func textInputView(_ view: TextInputView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if let characterPair = characterPairs.first(where: { $0.leading == text }) {
            let shouldInsertCharacterPair = editorDelegate?.editorTextView(self, shouldInsert: characterPair, in: range) ?? true
            if shouldInsertCharacterPair {
                insert(characterPair, in: range)
                return false
            } else {
                return editorDelegate?.editorTextView(self, shouldChangeTextIn: range, replacementText: text) ?? true
            }
        } else {
            return editorDelegate?.editorTextView(self, shouldChangeTextIn: range, replacementText: text) ?? true
        }
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
