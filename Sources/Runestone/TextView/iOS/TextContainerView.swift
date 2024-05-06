// swiftlint:disable file_length
#if os(iOS)
import UIKit

final class TextContainerView<LineManagerType: LineManaging>: UIView, UITextInput {
    var inputDelegate: UITextInputDelegate?
    
    override var frame: CGRect {
        didSet {
            if frame != oldValue {
                lineFragmentsHostView.frame = CGRect(origin: .zero, size: frame.size)
            }
        }
    }

    private let lineFragmentsHostView: UIView
    private let textInputClient: UITextInputClient<LineManagerType>

    init(textInputClient: UITextInputClient<LineManagerType>, lineFragmentsHostView: UIView) {
        self.textInputClient = textInputClient
        self.lineFragmentsHostView = lineFragmentsHostView
        super.init(frame: .zero)
        addSubview(lineFragmentsHostView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var beginningOfDocument: UITextPosition {
        textInputClient.beginningOfDocument
    }
    var endOfDocument: UITextPosition {
        textInputClient.endOfDocument
    }
    var hasText: Bool {
        textInputClient.hasText
    }
    var tokenizer: UITextInputTokenizer {
        textInputClient.tokenizer
    }

    // MARK: - Caret
    func caretRect(for position: UITextPosition) -> CGRect {
        textInputClient.caretRect(for: position)
    }

    func beginFloatingCursor(at point: CGPoint) {
        textInputClient.beginFloatingCursor(at: point)
    }

    func updateFloatingCursor(at point: CGPoint) {
        textInputClient.updateFloatingCursor(at: point)
    }

    func endFloatingCursor() {
        textInputClient.endFloatingCursor()
    }

    // MARK: - Editing
    func text(in range: UITextRange) -> String? {
        textInputClient.text(in: range)
    }

    func replace(_ range: UITextRange, withText text: String) {
        textInputClient.replace(range, withText: text)
    }

    func insertText(_ text: String) {
        textInputClient.insertText(text)
    }

    func deleteBackward() {
        textInputClient.deleteBackward()
    }

    // MARK: - Selection
    var selectedTextRange: UITextRange? {
        get {
            textInputClient.selectedTextRange
        }
        set {
            textInputClient.selectedTextRange = newValue
        }
    }

    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        textInputClient.selectionRects(for: range)
    }

    func firstRect(for range: UITextRange) -> CGRect {
        textInputClient.firstRect(for: range)
    }

    // MARK: - Marking
    var markedTextStyle: [NSAttributedString.Key: Any]? {
        get {
            textInputClient.markedTextStyle
        }
        set {
            textInputClient.markedTextStyle = newValue
        }
    }

    var markedTextRange: UITextRange? {
        get {
            textInputClient.markedTextRange
        }
        set {
            textInputClient.markedTextRange = newValue
        }
    }

    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        textInputClient.setMarkedText(markedText, selectedRange: selectedRange)
    }

    func setAttributedMarkedText(_ markedText: NSAttributedString?, selectedRange: NSRange) {
        textInputClient.setAttributedMarkedText(markedText, selectedRange: selectedRange)
    }

    func unmarkText() {
        textInputClient.unmarkText()
    }

    // MARK: - Navigation
    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        textInputClient.textRange(from: fromPosition, to: toPosition)
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        textInputClient.position(from: position, offset: offset)
    }

    func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        textInputClient.position(from: position, in: direction, offset: offset)
    }

    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        textInputClient.compare(position, to: other)
    }

    func offset(from: UITextPosition, to toPosition: UITextPosition) -> Int {
        textInputClient.offset(from: from, to: toPosition)
    }

    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        textInputClient.position(within: range, farthestIn: direction)
    }

    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        textInputClient.characterRange(byExtending: position, in: direction)
    }

    func closestPosition(to point: CGPoint) -> UITextPosition? {
        textInputClient.closestPosition(to: point)
    }

    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        textInputClient.closestPosition(to: point, within: range)
    }

    func characterRange(at point: CGPoint) -> UITextRange? {
        textInputClient.characterRange(at: point)
    }

    // MARK: - Writing Direction
    func baseWritingDirection(for position: UITextPosition, in direction: UITextStorageDirection) -> NSWritingDirection {
        textInputClient.baseWritingDirection(for: position, in: direction)
    }

    func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {
        textInputClient.setBaseWritingDirection(writingDirection, for: range)
    }
}
#endif
