//
//  EditorInputView.swift
//  
//
//  Created by Simon Støvring on 04/01/2021.
//

import UIKit
import CoreText

public final class EditorInputView: UIScrollView, UITextInput {
    public var text: String {
        get {
            return textView.string as String
        }
        set {
            textView.string = NSMutableString(string: newValue)
            contentSize = textView.contentSize
            layoutLines()
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
            if let indexedRange = newValue as? EditorIndexedRange {
                textView.selectedTextRange = indexedRange.range
            } else {
                textView.selectedTextRange = nil
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
    public private(set) lazy var tokenizer: UITextInputTokenizer = UITextInputStringTokenizer(textInput: self)
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
            textView.backgroundColor = newValue
        }
    }

    private let textView = EditorBackingView()
    private let tapGestureRecognizer = UITapGestureRecognizer()
    private let editingTextInteraction = UITextInteraction(for: .editable)
    private var _inputAccessoryView: UIView?
    private let queue = OperationQueue()
    private var isProcessingNewText = false

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
        textView.frame = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        if !isProcessingNewText {
            layoutLines()
        }
    }

    @discardableResult
    public override func becomeFirstResponder() -> Bool {
        let didBecomeFirstResponder = super.becomeFirstResponder()
        if didBecomeFirstResponder {
            tapGestureRecognizer.isEnabled = false
            addInteraction(editingTextInteraction)
        }
        return didBecomeFirstResponder
    }

    @discardableResult
    public override func resignFirstResponder() -> Bool {
        let didResignFirstResponder = super.resignFirstResponder()
        if didResignFirstResponder {
            textView.selectedTextRange = nil
            textView.markedTextRange = nil
            tapGestureRecognizer.isEnabled = true
            removeInteraction(editingTextInteraction)
        }
        return didResignFirstResponder
    }

    public func setText(_ text: String, completion: ((Bool) -> Void)? = nil) {
        assert(Thread.isMainThread, "\(#function) must be called on the main thread")
        isProcessingNewText = true
        textView.string = ""
        let operation = BlockOperation()
        operation.addExecutionBlock { [weak self, weak operation] in
            guard let self = self, let operation = operation else {
                completion?(false)
                return
            }
            guard !operation.isCancelled else {
                completion?(false)
                return
            }
            self.textView.string = NSMutableString(string: text)
            DispatchQueue.main.sync {
                self.isProcessingNewText = false
                if !operation.isCancelled {
                    self.layoutLines()
                }
            }
            completion?(!operation.isCancelled)
        }
        queue.addOperation(operation)
    }
}

// MARK: - Caret
public extension EditorInputView {
    func caretRect(for position: UITextPosition) -> CGRect {
        guard let indexedPosition = position as? EditorIndexedPosition else {
            fatalError("Expected position to be of type \(EditorIndexedPosition.self)")
        }
        return textView.caretRect(atIndex: indexedPosition.index)
    }
}

// MARK: - Editing
public extension EditorInputView {
    func insertText(_ text: String) {
        textView.insertText(text)
        layoutLines()
    }

    func deleteBackward() {
        textView.deleteBackward()
        layoutLines()
    }

    func replace(_ range: UITextRange, withText text: String) {
        if let indexedRange = range as? EditorIndexedRange {
            textView.replace(indexedRange.range, withText: text)
            layoutLines()
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
public extension EditorInputView {
    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
//        guard let indexedRange = range as? EditorIndexedRange else {
//            fatalError("Expected range to be of type \(EditorIndexedRange.self)")
//        }
        return []
    }
}

// MARK: - Marking
public extension EditorInputView {
    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        print("Mark text")
    }

    func unmarkText() {
        print("Unmark text")
    }
}

// MARK: - Ranges and Positions
public extension EditorInputView {
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
            newPosition += 1
        case .left:
            newPosition -= 1
        case .up, .down:
            break
        @unknown default:
            break
        }
        newPosition = min(max(newPosition, 0), textView.string.length)
        return EditorIndexedPosition(index: newPosition)
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
        let location = min(fromIndexedPosition.index, toIndexedPosition.index)
        let length = abs(toIndexedPosition.index - fromIndexedPosition.index)
        let range = NSRange(location: location, length: length)
        return EditorIndexedRange(range: range)
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        guard let indexedPosition = position as? EditorIndexedPosition else {
            return EditorIndexedPosition(index: 0)
        }
        let newPosition = indexedPosition.index + offset
        guard newPosition >= 0 && newPosition < textView.string.length else {
             return EditorIndexedPosition(index: 0)
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
}

// MARK: - Writing Direction
public extension EditorInputView {
    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection {
        return .natural
    }

    func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {}
}

// MARK: - Layout
private extension EditorInputView {
    private func layoutLines() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        textView.layoutLines(in: bounds)
        CATransaction.commit()
    }
}

// MARK: - Interaction
private extension EditorInputView {
    @objc private func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
        if !isFirstResponder {
            textView.markedTextRange = NSRange(location: NSNotFound, length: 0)
            textView.selectedTextRange = NSRange(location: 0, length: 0)
            becomeFirstResponder()
        }
    }
}

// MARK: - EditorBackingViewDelegate
extension EditorInputView: EditorBackingViewDelegate {
    func editorBackingViewDidInvalidateContentSize(_ view: EditorBackingView) {
        if contentSize != view.contentSize {
            contentSize = view.contentSize
        }
    }
}
