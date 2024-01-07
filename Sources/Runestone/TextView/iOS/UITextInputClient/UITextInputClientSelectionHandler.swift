import UIKit

final class UITextInputClientSelectionHandler {
    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        []
    }
    
    func firstRect(for range: UITextRange) -> CGRect {
        .zero
    }
}
