#if os(iOS)
import UIKit

final class UITextInputClient<LineManagerType: LineManaging> {
    let tokenizer: UITextInputTokenizer
    var beginningOfDocument: UITextPosition {
        navigationHandler.beginningOfDocument
    }
    var endOfDocument: UITextPosition {
        navigationHandler.endOfDocument
    }
    var hasText: Bool {
        textEditingHandler.hasText
    }

    private let textEditingHandler: UITextInputClientTextEditingHandler
    private let insertionPointHandler: UITextInputClientInsertionPointHandler
    private let navigationHandler: UITextInputClientNavigationHandler<LineManagerType>
    private let selectionHandler: UITextInputClientSelectionHandler<LineManagerType>
    private let markHandler: UITextInputClientMarkHandler

    init(
        tokenizer: UITextInputTokenizer,
        textEditingHandler: UITextInputClientTextEditingHandler,
        insertionPointHandler: UITextInputClientInsertionPointHandler,
        navigationHandler: UITextInputClientNavigationHandler<LineManagerType>,
        selectionHandler: UITextInputClientSelectionHandler<LineManagerType>,
        markHandler: UITextInputClientMarkHandler
    ) {
        self.tokenizer = tokenizer
        self.textEditingHandler = textEditingHandler
        self.insertionPointHandler = insertionPointHandler
        self.navigationHandler = navigationHandler
        self.selectionHandler = selectionHandler
        self.markHandler = markHandler
    }
}

// MARK: - Insertion Point
extension UITextInputClient {
    func caretRect(for position: UITextPosition) -> CGRect {
        insertionPointHandler.caretRect(for: position)
    }

    func beginFloatingCursor(at point: CGPoint) {
        insertionPointHandler.beginFloatingCursor(at: point)
    }

    func updateFloatingCursor(at point: CGPoint) {
        insertionPointHandler.updateFloatingCursor(at: point)
    }

    func endFloatingCursor() {
        insertionPointHandler.endFloatingCursor()
    }
}

// MARK: - Text Editing
extension UITextInputClient {
    func text(in range: UITextRange) -> String? {
        textEditingHandler.text(in: range)
    }

    func replace(_ range: UITextRange, withText text: String) {
        textEditingHandler.replace(range, withText: text)
    }

    func insertText(_ text: String) {
        textEditingHandler.insertText(text)
    }

    func deleteBackward() {
        textEditingHandler.deleteBackward()
    }

    func baseWritingDirection(
        for position: UITextPosition,
        in direction: UITextStorageDirection
    ) -> NSWritingDirection {
        textEditingHandler.baseWritingDirection(for: position, in: direction)
    }

    func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange) {
        textEditingHandler.setBaseWritingDirection(writingDirection, for: range)
    }
}

// MARK: - Selection
extension UITextInputClient {
    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        selectionHandler.selectionRects(for: range)
    }

    func firstRect(for range: UITextRange) -> CGRect {
        selectionHandler.firstRect(for: range)
    }
}

// MARK: - Marking
extension UITextInputClient {
    var markedTextStyle: [NSAttributedString.Key: Any]? {
        get {
            markHandler.markedTextStyle
        }
        set {
            markHandler.markedTextStyle = newValue
        }
    }

    var markedTextRange: UITextRange? {
        get {
            markHandler.markedTextRange
        }
        set {
            markHandler.markedTextRange = newValue
        }
    }

    func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        markHandler.setMarkedText(markedText, selectedRange: selectedRange)
    }

    func setAttributedMarkedText(_ markedText: NSAttributedString?, selectedRange: NSRange) {
        markHandler.setAttributedMarkedText(markedText, selectedRange: selectedRange)
    }

    func unmarkText() {
        markHandler.unmarkText()
    }
}

// MARK: - Navigation
extension UITextInputClient {
    var selectedTextRange: UITextRange? {
        get {
            navigationHandler.selectedTextRange
        }
        set {
            navigationHandler.selectedTextRange = newValue
        }
    }
    
    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange? {
        navigationHandler.textRange(from: fromPosition, to: toPosition)
    }

    func position(from position: UITextPosition, offset: Int) -> UITextPosition? {
        navigationHandler.position(from: position, offset: offset)
    }

    func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition? {
        navigationHandler.position(from: position, in: direction, offset: offset)
    }

    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult {
        navigationHandler.compare(position, to: other)
    }

    func offset(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> Int {
        navigationHandler.offset(from: fromPosition, to: toPosition)
    }

    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition? {
        navigationHandler.position(within: range, farthestIn: direction)
    }

    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange? {
        navigationHandler.characterRange(byExtending: position, in: direction)
    }

    func closestPosition(to point: CGPoint) -> UITextPosition? {
        navigationHandler.closestPosition(to: point)
    }

    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition? {
        navigationHandler.closestPosition(to: point, within: range)
    }

    func characterRange(at point: CGPoint) -> UITextRange? {
        navigationHandler.characterRange(at: point)
    }
}
#endif
