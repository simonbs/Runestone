#if os(iOS)
import UIKit

protocol UITextInputClient: AnyObject {
    var tokenizer: UITextInputTokenizer { get }
    var beginningOfDocument: UITextPosition { get }
    var endOfDocument: UITextPosition { get }
    var hasText: Bool { get }
    func caretRect(for position: UITextPosition) -> CGRect
    func beginFloatingCursor(at point: CGPoint)
    func updateFloatingCursor(at point: CGPoint)
    func endFloatingCursor()
    func text(in range: UITextRange) -> String?
    func replace(_ range: UITextRange, withText text: String)
    func insertText(_ text: String)
    func deleteBackward()
    func baseWritingDirection(
        for position: UITextPosition,
        in direction: UITextStorageDirection
    ) -> NSWritingDirection
    func setBaseWritingDirection(_ writingDirection: NSWritingDirection, for range: UITextRange)
    func selectionRects(for range: UITextRange) -> [UITextSelectionRect]
    func firstRect(for range: UITextRange) -> CGRect
    var markedTextStyle: [NSAttributedString.Key: Any]? { get set }
    var markedTextRange: UITextRange? { get set }
    func setMarkedText(_ markedText: String?, selectedRange: NSRange)
    func setAttributedMarkedText(_ markedText: NSAttributedString?, selectedRange: NSRange)
    func unmarkText()
    var selectedTextRange: UITextRange? { get set }
    func textRange(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> UITextRange?
    func position(from position: UITextPosition, offset: Int) -> UITextPosition?
    func position(from position: UITextPosition, in direction: UITextLayoutDirection, offset: Int) -> UITextPosition?
    func compare(_ position: UITextPosition, to other: UITextPosition) -> ComparisonResult
    func offset(from fromPosition: UITextPosition, to toPosition: UITextPosition) -> Int
    func position(within range: UITextRange, farthestIn direction: UITextLayoutDirection) -> UITextPosition?
    func characterRange(byExtending position: UITextPosition, in direction: UITextLayoutDirection) -> UITextRange?
    func closestPosition(to point: CGPoint) -> UITextPosition?
    func closestPosition(to point: CGPoint, within range: UITextRange) -> UITextPosition?
    func characterRange(at point: CGPoint) -> UITextRange?
}
#endif
