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
    public var theme: EditorTheme {
        get {
            return textInputView.theme
        }
        set {
            textInputView.theme = newValue
        }
    }
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
    public var insertionPointColor: UIColor {
        get {
            return textInputView.insertionPointColor
        }
        set {
            textInputView.insertionPointColor = newValue
        }
    }
    public var selectionBarColor: UIColor {
        get {
            return textInputView.selectionBarColor
        }
        set {
            textInputView.selectionBarColor = newValue
        }
    }
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
    public var characterPairs: [EditorCharacterPair] = []
    public var showLineNumbers: Bool {
        get {
            return textInputView.showLineNumbers
        }
        set {
            textInputView.showLineNumbers = newValue
        }
    }
    public var gutterLeadingPadding: CGFloat {
        get {
            return textInputView.gutterLeadingPadding
        }
        set {
            textInputView.gutterLeadingPadding = newValue
        }
    }
    public var gutterTrailingPadding: CGFloat {
        get {
            return textInputView.gutterTrailingPadding
        }
        set {
            textInputView.gutterTrailingPadding = newValue
        }
    }
    public var gutterMargin: CGFloat {
        get {
            return textInputView.gutterMargin
        }
        set {
            textInputView.gutterMargin = newValue
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

    public func setState(_ state: EditorState) {
        textInputView.setState(state)
        contentSize = textInputView.contentSize
    }

    public func linePosition(at location: Int) -> LinePosition? {
        return textInputView.linePosition(at: location)
    }

    public func setLanguage(_ language: Language?, completion: ((Bool) -> Void)? = nil) {
        textInputView.setLanguage(language, completion: completion)
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
