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

public final class EditorTextView: UIScrollView, UITextInput {
    public weak var editorDelegate: EditorTextViewDelegate?
    public var text: String {
        get {
            return textView.string as String
        }
        set {
            textView.string = NSMutableString(string: newValue)
            contentSize = textView.contentSize
            setNeedsDisplay()
        }
    }
    public var font: UIFont? {
        get {
            return textView.font
        }
        set {
            textView.font = newValue
        }
    }
    public var textColor: UIColor {
        get {
            return textView.textColor
        }
        set {
            textView.textColor = newValue
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
    public var selectedTextRange: UITextRange? {
        get {
            if let range = textView.selectedTextRange {
                return EditorIndexedRange(range: range)
            } else {
                return nil
            }
        }
        set {
            let newRange = (newValue as? EditorIndexedRange)?.range
            if newRange != textView.selectedTextRange {
                inputDelegate?.selectionWillChange(self)
                textView.selectedTextRange = newRange
                inputDelegate?.selectionDidChange(self)
            }
        }
    }
    public private(set) var markedTextRange: UITextRange?
    public var markedTextStyle: [NSAttributedString.Key: Any]?
    public var beginningOfDocument: UITextPosition {
        return EditorIndexedPosition(index: 0)
    }
    public var endOfDocument: UITextPosition {
        return EditorIndexedPosition(index: textView.string.length)
    }
    public var inputDelegate: UITextInputDelegate?
    public private(set) lazy var tokenizer: UITextInputTokenizer = EditorTextInputStringTokenizer(textInput: self, lineManager: textView.lineManager)
    public var hasText: Bool {
        return textView.string.length > 0
    }
    public override var canBecomeFirstResponder: Bool {
        return true
    }
    public override var backgroundColor: UIColor? {
        get {
            return textView.backgroundColor
        }
        set {
            super.backgroundColor = newValue
            textView.backgroundColor = newValue
        }
    }
    public override var contentOffset: CGPoint {
        didSet {
            if contentOffset != oldValue {
                textView.viewport = CGRect(origin: contentOffset, size: frame.size)
            }
        }
    }
    public var theme: EditorTheme {
        get {
            return textView.theme
        }
        set {
            textView.theme = newValue
        }
    }
    public var autocorrectionType: UITextAutocorrectionType = .default
    public var autocapitalizationType: UITextAutocapitalizationType = .sentences
    public var smartQuotesType: UITextSmartQuotesType = .default
    public var smartDashesType: UITextSmartDashesType = .default
    public var smartInsertDeleteType: UITextSmartInsertDeleteType = .default
    public var spellCheckingType: UITextSpellCheckingType = .default
    public var keyboardType: UIKeyboardType = .default
    public var keyboardAppearance: UIKeyboardAppearance = .default
    public var returnKeyType: UIReturnKeyType = .default
    @objc public var insertionPointColor: UIColor = .black
    @objc public var selectionBarColor: UIColor = .black
    @objc public var selectionHighlightColor: UIColor = .black

    private var _inputAccessoryView: UIView?
    private let textView = EditorBackingView()
    private let tapGestureRecognizer = UITapGestureRecognizer()
    private let editingTextInteraction = UITextInteraction(for: .editable)
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

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        textView.delegate = self
        textView.isUserInteractionEnabled = false
        editingTextInteraction.textInput = self
        tapGestureRecognizer.addTarget(self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGestureRecognizer)
        addSubview(textView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = CGRect(x: 0, y: bounds.minY, width: bounds.width, height: bounds.height)
        textView.viewport = CGRect(origin: contentOffset, size: frame.size)
        layoutTextSelectionView()
    }

    @discardableResult
    public override func becomeFirstResponder() -> Bool {
        let wasFirstResponder = isFirstResponder
        let didBecomeFirstResponder = super.becomeFirstResponder()
        if !wasFirstResponder && isFirstResponder {
            textView.markedTextRange = nil
            if selectedTextRange == nil {
                textView.selectedTextRange = NSRange(location: 0, length: 0)
            }
            tapGestureRecognizer.isEnabled = false
            addInteraction(editingTextInteraction)
        }
        return didBecomeFirstResponder
    }

    @discardableResult
    public override func resignFirstResponder() -> Bool {
        let wasFirstResponder = isFirstResponder
        let didResignFirstResponder = super.resignFirstResponder()
        if wasFirstResponder && !isFirstResponder {
            textView.selectedTextRange = nil
            textView.markedTextRange = nil
            tapGestureRecognizer.isEnabled = true
            removeInteraction(editingTextInteraction)
        }
        return didResignFirstResponder
    }

    public func setState(_ state: EditorState) {
        textView.setState(state)
    }
}

// MARK: - Layout
private extension EditorTextView {
    private func layoutTextSelectionView() {
        if let textSelectionView = textSelectionView {
            let currentFrame = textSelectionView.frame
            let newYPosition = -adjustedContentInset.top
            let newHeight = frame.height + contentOffset.y
            textSelectionView.frame = CGRect(x: currentFrame.minX, y: newYPosition, width: currentFrame.width, height: newHeight)
        }
    }
}

// MARK: - Caret
public extension EditorTextView {
    func caretRect(for position: UITextPosition) -> CGRect {
        guard let indexedPosition = position as? EditorIndexedPosition else {
            fatalError("Expected position to be of type \(EditorIndexedPosition.self)")
        }
        return textView.caretRect(atIndex: indexedPosition.index)
    }
}

// MARK: - Editing
public extension EditorTextView {
    func insertText(_ text: String) {
        inputDelegate?.textWillChange(self)
        textView.insertText(text)
        setNeedsDisplay()
        inputDelegate?.textDidChange(self)
        editorDelegate?.editorTextViewDidChange(self)
    }

    func deleteBackward() {
        inputDelegate?.textWillChange(self)
        textView.deleteBackward()
        setNeedsDisplay()
        inputDelegate?.textDidChange(self)
        editorDelegate?.editorTextViewDidChange(self)
    }

    func replace(_ range: UITextRange, withText text: String) {
        if let indexedRange = range as? EditorIndexedRange {
            inputDelegate?.textWillChange(self)
            textView.replace(indexedRange.range, withText: text)
            setNeedsDisplay()
            inputDelegate?.textDidChange(self)
            editorDelegate?.editorTextViewDidChange(self)
        }
    }

    func text(in range: UITextRange) -> String? {
        if let indexedRange = range as? EditorIndexedRange {
            return textView.text(in: indexedRange.range)
        } else {
            return nil
        }
    }
}

// MARK: - Selection
public extension EditorTextView {
    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        layoutTextSelectionView()
        if let indexedRange = range as? EditorIndexedRange {
            return textView.selectionRects(in: indexedRange.range)
        } else {
            return []
        }
    }
}

// MARK: - Marking
public extension EditorTextView {
    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {}

    func unmarkText() {}
}

// MARK: - Ranges and Positions
public extension EditorTextView {
    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        return nil
    }

    func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        guard let indexedPosition = position as? EditorIndexedPosition else {
            return nil
        }
        var newPosition = indexedPosition.index
        switch direction {
        case .right:
            newPosition += offset
        case .left:
            newPosition -= offset
        case .up:
            newPosition = targetPositionForMovingFromLine(containingCharacterAt: indexedPosition.index, lineOffset: offset * -1)
        case .down:
            newPosition = targetPositionForMovingFromLine(containingCharacterAt: indexedPosition.index, lineOffset: offset)
        @unknown default:
            break
        }
        if newPosition >= 0 && newPosition <= textView.string.length {
            return EditorIndexedPosition(index: newPosition)
        } else {
            return nil
        }
    }

    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        return nil
    }

    func characterRange(at point: CGPoint) -> UITextRange? {
        return nil
    }

    func firstRect(for range: UITextRange) -> CGRect {
        guard let indexedRange = range as? EditorIndexedRange else {
            fatalError("Expected range to be of type \(EditorIndexedRange.self)")
        }
        return textView.firstRect(for: indexedRange.range)
    }

    func closestPosition(to point: CGPoint) -> UITextPosition? {
        if let index = textView.closestIndex(to: point) {
            return EditorIndexedPosition(index: index)
        } else {
            return nil
        }
    }

    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        return nil
    }

    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        guard let fromIndexedPosition = fromPosition as? EditorIndexedPosition, let toIndexedPosition = toPosition as? EditorIndexedPosition else {
            return nil
        }
        let range = NSRange(location: fromIndexedPosition.index, length: toIndexedPosition.index - fromIndexedPosition.index)
        return EditorIndexedRange(range: range)
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        guard let indexedPosition = position as? EditorIndexedPosition else {
            return nil
        }
        let newPosition = indexedPosition.index + offset
        guard newPosition >= 0 && newPosition <= textView.string.length else {
            return nil
        }
        return EditorIndexedPosition(index: newPosition)
    }

    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        guard let indexedPosition = position as? EditorIndexedPosition, let otherIndexedPosition = other as? EditorIndexedPosition else {
            fatalError("Positions must be of type \(EditorIndexedPosition.self)")
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
        if let fromPosition = from as? EditorIndexedPosition, let toPosition = toPosition as? EditorIndexedPosition {
            return toPosition.index - fromPosition.index
        } else {
            return 0
        }
    }

    private func targetPositionForMovingFromLine(containingCharacterAt sourceIndex: Int, lineOffset: Int) -> Int {
        guard let currentLinePosition = textView.lineManager.linePosition(at: sourceIndex) else {
            return sourceIndex
        }
        let targetLineNumber = min(max(currentLinePosition.lineNumber + lineOffset, 0), textView.lineManager.lineCount - 1)
        let targetLine = textView.lineManager.line(atIndex: targetLineNumber)
        let localLineIndex = min(currentLinePosition.column, targetLine.data.length)
        return targetLine.location + localLineIndex
    }
}

// MARK: - Writing Direction
public extension EditorTextView {
    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection {
        return .natural
    }

    func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {}
}

// MARK: - Interaction
private extension EditorTextView {
    @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        if !isFirstResponder {
            let point = gestureRecognizer.location(in: self)
            if let position = closestPosition(to: point) as? EditorIndexedPosition {
                textView.selectedTextRange = NSRange(location: position.index, length: 0)
            }
            becomeFirstResponder()
        }
    }
}

// MARK: - EditorBackingViewDelegate
extension EditorTextView: EditorBackingViewDelegate {
    func editorBackingViewDidInvalidateContentSize(_ view: EditorBackingView) {
        if contentSize != view.contentSize {
            contentSize = view.contentSize
        }
    }
}
