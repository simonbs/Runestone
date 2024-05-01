#if os(iOS)
import UIKit

final class UITextInputClientSelectionHandler<LineManagerType: LineManaging> {
    private let textSelectionRectProvider: TextSelectionRectProvider<LineManagerType>
    private let firstRectProvider: FirstRectProvider<LineManagerType>

    init(
        textSelectionRectProvider: TextSelectionRectProvider<LineManagerType>,
        firstRectProvider: FirstRectProvider<LineManagerType>
    ) {
        self.textSelectionRectProvider = textSelectionRectProvider
        self.firstRectProvider = firstRectProvider
    }

    func selectionRects(for range: UITextRange) -> [UITextSelectionRect] {
        guard let range = range as? RunestoneUITextRange else {
            fatalError("Expected range to be of type \(RunestoneUITextRange.self) but got \(type(of: range))")
        }
        return textSelectionRectProvider.textSelectionRects(in: range.range)
    }
    
    func firstRect(for range: UITextRange) -> CGRect {
        guard let range = range as? RunestoneUITextRange else {
            fatalError("Expected range to be of type \(RunestoneUITextRange.self) but got \(type(of: range))")
        }
        return firstRectProvider.firstRect(for: range.range)
    }
}
#endif
