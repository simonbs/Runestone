//
//  EditorTextView.swift
//  
//
//  Created by Simon Støvring on 04/01/2021.
//

import UIKit
import CoreText

public protocol EditorTextViewDelegate: AnyObject {
    func editorTextViewDidChange(_ textView: EditorTextView)
}

public extension EditorTextViewDelegate {
    func editorTextViewDidChange(_ textView: EditorTextView) {}
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
    public var font: UIFont? {
        get {
            return textInputView.font
        }
        set {
            textInputView.font = newValue
        }
    }
    public var textColor: UIColor {
        get {
            return textInputView.textColor
        }
        set {
            textInputView.textColor = newValue
        }
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

    private let textInputView = EditorTextInputView()
    private let editingTextInteraction = UITextInteraction(for: .editable)
    private var _inputAccessoryView: UIView?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        textInputView.delegate = self
        editingTextInteraction.textInput = textInputView
        addSubview(textInputView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        textInputView.frame = CGRect(x: 0, y: 0, width: frame.width, height: contentSize.height)
        textInputView.viewport = CGRect(origin: contentOffset, size: frame.size)
    }

    public func setState(_ state: EditorState) {
        textInputView.setState(state)
        contentSize = textInputView.contentSize
    }
}

// MARK: - EditorTextInputViewDelegate
extension EditorTextView: EditorTextInputViewDelegate {
    func editorTextInputViewDidBeginEditing(_ view: EditorTextInputView) {
        addInteraction(editingTextInteraction)
    }

    func editorTextInputViewDidEndEditing(_ view: EditorTextInputView) {
        removeInteraction(editingTextInteraction)
    }

    func editorTextInputViewDidInvalidateContentSize(_ view: EditorTextInputView) {
        if contentSize != view.contentSize {
            contentSize = view.contentSize
        }
    }
}
