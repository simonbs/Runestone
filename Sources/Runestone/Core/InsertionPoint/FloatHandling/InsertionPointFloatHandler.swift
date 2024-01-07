import CoreGraphics

struct InsertionPointFloatHandler: InsertionPointFloatHandling {
    func beginFloatingInsertionPoint(at point: CGPoint) {
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

    func updateFloatingInsertionPoint(at point: CGPoint) {
//        guard let floatingInsertionPointView, let position = closestPosition(to: point) else {
//            return
//        }
//        floatingInsertionPointPosition.value = point
//        let caretRect = caretRect(for: position)
//        let caretOrigin = CGPoint(x: point.x - caretRect.width / 2, y: point.y - caretRect.height / 2)
//        floatingInsertionPointView.frame = CGRect(origin: caretOrigin, size: caretRect.size)

    }

    func endFloatingInsertionPoint() {
//        floatingInsertionPointPosition.value = nil
//        floatingInsertionPointView?.removeFromSuperview()
//        floatingInsertionPointView = nil
//        textViewDelegate.textViewDidEndFloatingCursor()
    }
}
