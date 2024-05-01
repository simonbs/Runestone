#if os(iOS)
import UIKit

final class UITextInputClientInsertionPointHandler {
    private let rectProvider: InsertionPointRectProviding
    private let floatHandler: InsertionPointFloatHandling

    init(
        rectProvider: InsertionPointRectProviding,
        floatHandler: InsertionPointFloatHandling
    ) {
        self.rectProvider = rectProvider
        self.floatHandler = floatHandler
    }

    func caretRect(for position: UITextPosition) -> CGRect {
        guard let position = position as? RunestoneUITextPosition else {
            fatalError("Expected position to be of type \(RunestoneUITextPosition.self)")
        }
        return rectProvider.insertionPointRect(atLocation: position.location)
    }

    func beginFloatingCursor(at point: CGPoint) {
//        guard let view = proxyView.view, floatingInsertionPointView == nil, let position = closestPosition(to: point) else {
//            return
//        }
//        floatingInsertionPointPosition.value = point
//        let caretRect = caretRect(for: position)
//        let caretOrigin = CGPoint(x: point.x - caretRect.width / 2, y: point.y - caretRect.height / 2)
//        let insertionPointView = insertionPointViewFactory.makeView()
//        insertionPointView.isFloating = true
//        insertionPointView.layer.zPosition = 5000
//        insertionPointView.frame = CGRect(origin: caretOrigin, size: caretRect.size)
//        view.addSubview(insertionPointView)
//        self.floatingInsertionPointView = insertionPointView
//        textViewDelegate.textViewDidBeginFloatingCursor()
    }

    func updateFloatingCursor(at point: CGPoint) {
//        guard let floatingInsertionPointView, let position = closestPosition(to: point) else {
//            return
//        }
//        floatingInsertionPointPosition.value = point
//        let caretRect = caretRect(for: position)
//        let caretOrigin = CGPoint(x: point.x - caretRect.width / 2, y: point.y - caretRect.height / 2)
//        floatingInsertionPointView.frame = CGRect(origin: caretOrigin, size: caretRect.size)
    }

    func endFloatingCursor() {
//        floatingInsertionPointPosition.value = nil
//        floatingInsertionPointView?.removeFromSuperview()
//        floatingInsertionPointView = nil
//        textViewDelegate.textViewDidEndFloatingCursor()
    }
}
#endif
