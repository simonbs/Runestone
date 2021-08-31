//
//  TextView.swift
//  
//
//  Created by Simon Støvring on 04/01/2021.
//

import CoreText
import UIKit

public protocol TextViewDelegate: AnyObject {
    func textViewShouldBeginEditing(_ textView: TextView) -> Bool
    func textViewShouldEndEditing(_ textView: TextView) -> Bool
    func textViewDidBeginEditing(_ textView: TextView)
    func textViewDidEndEditing(_ textView: TextView)
    func textViewDidChange(_ textView: TextView)
    func textViewDidChangeSelection(_ textView: TextView)
    func textView(_ textView: TextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool
    func textView(_ textView: TextView, shouldInsert characterPair: CharacterPair, in range: NSRange) -> Bool
    func textView(_ textView: TextView, shouldSkipTrailingComponentOf characterPair: CharacterPair, in range: NSRange) -> Bool
    func textViewDidUpdateGutterWidth(_ textView: TextView)
    func textViewDidBeginFloatingCursor(_ view: TextView)
    func textViewDidEndFloatingCursor(_ view: TextView)
    func textViewDidBeginDraggingCursor(_ view: TextView)
    func textViewDidEndDraggingCursor(_ view: TextView)
}

public extension TextViewDelegate {
    func textViewShouldBeginEditing(_ textView: TextView) -> Bool {
        return true
    }
    func textViewShouldEndEditing(_ textView: TextView) -> Bool {
        return true
    }
    func textViewDidBeginEditing(_ textView: TextView) {}
    func textViewDidEndEditing(_ textView: TextView) {}
    func textViewDidChange(_ textView: TextView) {}
    func textViewDidChangeSelection(_ textView: TextView) {}
    func textView(_ textView: TextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        return true
    }
    func textView(_ textView: TextView, shouldInsert characterPair: CharacterPair, in range: NSRange) -> Bool {
        return true
    }
    func textView(_ textView: TextView, shouldSkipTrailingComponentOf characterPair: CharacterPair, in range: NSRange) -> Bool {
        return true
    }
    func textViewDidUpdateGutterWidth(_ textView: TextView) {}
    func textViewDidBeginFloatingCursor(_ view: TextView) {}
    func textViewDidEndFloatingCursor(_ view: TextView) {}
    func textViewDidBeginDraggingCursor(_ view: TextView) {}
    func textViewDidEndDraggingCursor(_ view: TextView) {}
}

public final class TextView: UIScrollView {
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
    public var text: String {
        get {
            return textInputView.string as String
        }
        set {
            textInputView.string = newValue as NSString
            contentSize = textInputView.contentSize
        }
    }
    /// Colors and fonts to be used by the editor.
    public var theme: Theme {
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
    public override var inputAssistantItem: UITextInputAssistantItem {
        return textInputView.inputAssistantItem
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
    public var characterPairs: [CharacterPair] {
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
    public var lineSelectionDisplayType: LineSelectionDisplayType {
        get {
            return textInputView.lineSelectionDisplayType
        }
        set {
            textInputView.lineSelectionDisplayType = newValue
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
    /// The strategy used when indenting text.
    public var indentStrategy: IndentStrategy {
        get {
            return textInputView.indentStrategy
        }
        set {
            textInputView.indentStrategy = newValue
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
    /// The text view shows a page guide when enabled. Use `pageGuideColumn` to specify the location of the page guide.
    public var showPageGuide: Bool {
        get {
            return textInputView.showPageGuide
        }
        set {
            textInputView.showPageGuide = newValue
        }
    }
    /// Specifies the location of the page guide. Use `showPageGuide` to specify if the page guide should be shown.
    public var pageGuideColumn: Int {
        get {
            return textInputView.pageGuideColumn
        }
        set {
            textInputView.pageGuideColumn = newValue
        }
    }
    /// Automatically scrolls the text view to show the caret when typing or moving the caret.
    public var isAutomaticScrollEnabled = true
    /// When automatic scrolling is enabled and the caret leaves the viewport, the text view will automatically scroll the content. The `automaticScrollInset` is applied to the viewport before scrolling. The inset can be used to adjust when the text view should scroll the content. For example it can be used to account for views overlaying the content. The text view will automatically account for the keyboard but will not account for the status bar.
    public var automaticScrollInset: UIEdgeInsets = .zero
    /// The length of the line that was longest when opening the document. This will return nil if the line is no longer available.
    /// The value will not be kept updated as the text is changed. The value can be used to determine if a document contains a very long line in which case the performance may be degraded when editing the line.
    public var lengthOfInitallyLongestLine: Int? {
        return textInputView.lineManager.initialLongestLine?.data.totalLength
    }

    private let textInputView: TextInputView
    private let editableTextInteraction = UITextInteraction(for: .editable)
    private let nonEditableTextInteraction = UITextInteraction(for: .nonEditable)
    private let tapGestureRecognizer = QuickTapGestureRecognizer()
    private var _inputAccessoryView: UIView?
    private let _inputAssistantItem = UITextInputAssistantItem()
    private var shouldBeginEditing: Bool {
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
    private var isAdjustingCursor = false
    private let keyboardObserver = KeyboardObserver()

    public override init(frame: CGRect) {
        textInputView = TextInputView(theme: DefaultTheme())
        super.init(frame: frame)
        backgroundColor = .white
        textInputView.delegate = self
        textInputView.editorView = self
        editableTextInteraction.textInput = textInputView
        nonEditableTextInteraction.textInput = textInputView
        addSubview(textInputView)
        tapGestureRecognizer.delegate = self
        tapGestureRecognizer.addTarget(self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGestureRecognizer)
        installNonEditableInteraction()
        keyboardObserver.delegate = self
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
        layoutIfNeeded()
    }

    @discardableResult
    public override func becomeFirstResponder() -> Bool {
        if !isEditing && shouldBeginEditing {
            _ = textInputView.resignFirstResponder()
            _ = textInputView.becomeFirstResponder()
            return true
        } else {
            return false
        }
    }

    @discardableResult
    public override func resignFirstResponder() -> Bool {
        if isEditing && shouldEndEditing {
            return textInputView.resignFirstResponder()
        } else {
            return false
        }
    }

    public override func reloadInputViews() {
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
    public func setState(_ state: TextViewState) {
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

    /// Attempts to detect the indent strategy used in the document. This may return an unknown strategy even
    /// when the document contains indentation.
    public func detectIndentStrategy() -> DetectedIndentStrategy {
        return textInputView.detectIndentStrategy()
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
        scroll(to: line.location)
        layoutIfNeeded()
        switch selection {
        case .beginning:
            textInputView.selectedTextRange = IndexedRange(location: line.location, length: 0)
        case .end:
            textInputView.selectedTextRange = IndexedRange(location: line.data.length, length: 0)
        case .line:
            textInputView.selectedTextRange = IndexedRange(location: line.location, length: line.data.length)
        }
        return true
    }

    public func search(for query: SearchQuery) -> [SearchResult] {
        guard !query.text.isEmpty else {
            return []
        }
        do {
            let regex = try query.makeRegularExpression()
            let range = NSRange(location: 0, length: textInputView.string.length)
            let matches = regex.matches(in: text, options: [], range: range)
            return matches.compactMap(searchResult(from:))
        } catch {
            print(error)
            return []
        }
    }

    public func attributedStringProvider(forRow row: Int) -> AttributedStringProvider? {
        return textInputView.attributedStringProvider(forRow: row)
    }
}

private extension TextView {
    @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        if tapGestureRecognizer.state == .ended {
            let point = gestureRecognizer.location(in: textInputView)
            let oldSelectedTextRange = selectedTextRange
            textInputView.moveCaret(to: point)
            if selectedTextRange != oldSelectedTextRange {
                layoutIfNeeded()
                editorDelegate?.textViewDidChangeSelection(self)
            }
            installEditableInteraction()
            becomeFirstResponder()
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

    private func skipInsertingTrailingComponent(of characterPair: CharacterPair, in range: NSRange) -> Bool {
        // If the user is typing the trailing component of a character pair, e.g. ) or } and the cursor is just in front
        // of that character, then we give the delegate the option to skip inserting the character. In that case we
        // move the caret to after the character in front of it instead.
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
                let oldContentOffset = contentOffset
                contentSize = textInputView.contentSize
                contentOffset = oldContentOffset
                setNeedsLayout()
            }
        }
    }

    private func scroll(to location: Int, animated: Bool = false) {
        let caretRect = textInputView.caretRect(at: location)
        let viewportMinX = contentOffset.x + automaticScrollInset.left + gutterWidth
        let viewportMinY = contentOffset.y + automaticScrollInset.top
        let viwportHeight = frame.height
            - keyboardObserver.keyboardHeight
            - automaticScrollInset.top
            - automaticScrollInset.bottom
        let viewportWidth = frame.width
            - gutterWidth
            - automaticScrollInset.left
            - automaticScrollInset.right
        let viewport = CGRect(x: viewportMinX, y: viewportMinY, width: viewportWidth, height: viwportHeight)
        var newContentOffset = contentOffset
        if caretRect.minX < viewport.minX {
            newContentOffset.x = caretRect.minX - gutterWidth - automaticScrollInset.left
        }
        if caretRect.maxX > viewport.maxX {
            newContentOffset.x = caretRect.minX - viewport.width - gutterWidth + automaticScrollInset.right
        }
        if caretRect.minY < viewport.minY {
            newContentOffset.y = caretRect.minY - automaticScrollInset.top
        }
        if caretRect.maxY > viewport.maxY {
            newContentOffset.y = caretRect.maxY - viewport.height - automaticScrollInset.top
        }
        if newContentOffset != contentOffset {
            setContentOffset(newContentOffset, animated: animated)
        }
    }

    private func installEditableInteraction() {
        if editableTextInteraction.view == nil {
            isInputAccessoryViewEnabled = true
            uninstallListenersForGestureRecognizers(attachedTo: nonEditableTextInteraction)
            removeInteraction(nonEditableTextInteraction)
            addInteraction(editableTextInteraction)
            installListenersForGestureRecognizers(attachedTo: editableTextInteraction)
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

    private func installListenersForGestureRecognizers(attachedTo textInteraction: UITextInteraction) {
        for gestureRecognizer in editableTextInteraction.gesturesForFailureRequirements {
            if gestureRecognizer is UILongPressGestureRecognizer {
                gestureRecognizer.addTarget(self, action: #selector(handleLoupeGesture(from:)))
            }
        }
    }

    private func uninstallListenersForGestureRecognizers(attachedTo textInteraction: UITextInteraction) {
        for gestureRecognizer in editableTextInteraction.gesturesForFailureRequirements {
            if gestureRecognizer is UILongPressGestureRecognizer {
                gestureRecognizer.removeTarget(self, action: #selector(handleLoupeGesture(from:)))
            }
        }
    }

    @objc private func handleLoupeGesture(from gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state == .began {
            isAdjustingCursor = true
            editorDelegate?.textViewDidBeginDraggingCursor(self)
        } else if gestureRecognizer.state == .ended {
            isAdjustingCursor = false
            editorDelegate?.textViewDidEndDraggingCursor(self)
        }
    }

    private func searchResult(from textCheckingResult: NSTextCheckingResult) -> SearchResult? {
        let range = textCheckingResult.range
        let lineManager = textInputView.lineManager
        guard let startLinePosition = lineManager.linePosition(at: range.lowerBound) else {
            return nil
        }
        guard let endLinePosition = lineManager.linePosition(at: range.upperBound) else {
            return nil
        }
        let firstLine = lineManager.line(atRow: startLinePosition.row)
        let firstLineLocalLocation = range.location - firstLine.location
        let firstLineLocalLength = min(range.length, firstLine.data.length - firstLineLocalLocation)
        let firstLineLocalRange = NSRange(location: firstLineLocalLocation, length: firstLineLocalLength)
        return SearchResult(range: range, firstLineLocalRange: firstLineLocalRange, startLinePosition: startLinePosition, endLinePosition: endLinePosition)
    }
}

// MARK: - TextInputViewDelegate
extension TextView: TextInputViewDelegate {
    func textInputViewDidBeginEditing(_ view: TextInputView) {
        isEditing = true
        if textInputView.selectedTextRange == nil {
            textInputView.selectedTextRange = IndexedRange(location: 0, length: 0)
        }
        installEditableInteraction()
        editorDelegate?.textViewDidBeginEditing(self)
    }

    func textInputViewDidEndEditing(_ view: TextInputView) {
        isEditing = false
        textInputView.selectedTextRange = nil
        installNonEditableInteraction()
        editorDelegate?.textViewDidEndEditing(self)
    }

    func textInputViewDidChange(_ view: TextInputView) {
        if isAutomaticScrollEnabled, !isAdjustingCursor, let newRange = textInputView.selectedRange, newRange.length == 0 {
            scroll(to: newRange.location)
        }
        editorDelegate?.textViewDidChange(self)
    }

    func textInputViewDidChangeSelection(_ view: TextInputView) {
        if isAutomaticScrollEnabled, !isAdjustingCursor, let newRange = textInputView.selectedRange, newRange.length == 0 {
            scroll(to: newRange.location)
        }
        editorDelegate?.textViewDidChangeSelection(self)
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
            return editorDelegate?.textView(self, shouldChangeTextIn: range, replacementText: text) ?? true
        }
    }

    func textInputViewDidUpdateGutterWidth(_ view: TextInputView) {
        editorDelegate?.textViewDidUpdateGutterWidth(self)
    }

    func textInputViewDidBeginFloatingCursor(_ view: TextInputView) {
        editorDelegate?.textViewDidBeginFloatingCursor(self)
    }

    func textInputViewDidEndFloatingCursor(_ view: TextInputView) {
        editorDelegate?.textViewDidEndFloatingCursor(self)
    }
}

// MARK: - UIGestureRecognizerDelegate
extension TextView: UIGestureRecognizerDelegate {
    public override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === tapGestureRecognizer {
            return !isEditing && shouldBeginEditing
        } else {
            return true
        }
    }
}

// MARK: - KeyboardObserverDelegate
extension TextView: KeyboardObserverDelegate {
    func keyboardObserver(_ keyboardObserver: KeyboardObserver, keyboardWillShowWithHeight keyboardHeight: CGFloat, animation: KeyboardObserver.Animation?) {
        if isAutomaticScrollEnabled, !isAdjustingCursor, let newRange = textInputView.selectedRange, newRange.length == 0 {
            scroll(to: newRange.location)
        }
    }
}
