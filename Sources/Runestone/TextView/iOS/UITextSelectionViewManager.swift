#if os(iOS)
import Combine
import UIKit

final class UITextSelectionViewManager {
    var containsCaret: Bool {
        textSelectionView?.subviews.count == 1
    }

    private let _textView: CurrentValueSubject<WeakBox<TextView>, Never>
    private let insertionPointShape: CurrentValueSubject<InsertionPointShape, Never>
    private let isInsertionPointPickedUp: CurrentValueSubject<Bool, Never>
    private var subviewsObserver: NSKeyValueObservation?
    private var asd: NSKeyValueObservation?
    private var cancellables: Set<AnyCancellable> = []
    private let v = InsertionPointView(renderer: InsertionPointCompositeRenderer(renderers: []))
    private var textView: TextView? {
        _textView.value.value
    }

    init(
        textView: CurrentValueSubject<WeakBox<TextView>, Never>,
        insertionPointShape: CurrentValueSubject<InsertionPointShape, Never>,
        isInsertionPointPickedUp: CurrentValueSubject<Bool, Never>
    ) {
        self._textView = textView
        self.insertionPointShape = insertionPointShape
        self.isInsertionPointPickedUp = isInsertionPointPickedUp
        insertionPointShape.sink { [weak self] _ in
            self?.hideCaretIfNeeded()
            self?.updateFloatingCursorAppearanceIfNeeded()
        }.store(in: &cancellables)
    }

    func hideCaretIfNeeded() {
        caretView?.backgroundColor = .clear
    }

    func updateFloatingCursorAppearanceIfNeeded() {
        textSelectionView?.layer.zPosition = 5000

//        caretView?.backgroundColor = .red
//        floatingCaretView?.backgroundColor = .purple



//        let subviews = textSelectionView?.subviews ?? []
////        subviews.first?.backgroundColor = .clear
//        print(subviews.map(\.tag))
//        guard subviews.count == 2 else {
//            return
//        }
//        let floatingCursorView = subviews[0]
//
//        switch insertionPointShape.value {
//        case .verticalBar:
//            floatingCursorView.layer.cornerRadius = floatingCursorView.bounds.width / 2
//        case .underline:
//            floatingCursorView.layer.cornerRadius = floatingCursorView.bounds.height / 2
//        case .block:
//            floatingCursorView.layer.cornerRadius = 0
//        }
    }

    func setupCaretViewObserver() {
        // UIView.subviews isn't observable but CALayer.sublayers is. So we use the sublayers property to detect when the subviews of UITextSelectionView has changed so we can hide the caret if needed.
        subviewsObserver = textSelectionView?.layer.observe(\.sublayers, options: .new) { [weak self] _, change in
            guard let self else {
                return
            }
            self.hideCaretIfNeeded()
            self.updateFloatingCursorAppearanceIfNeeded()
            if let floatingCaretView = self.floatingCaretView {
                print(change.newValue??.contains(where: { $0 === floatingCaretView.layer }))
                self.isInsertionPointPickedUp.value = change.newValue??.contains(floatingCaretView.layer) ?? false
            } else {
                self.isInsertionPointPickedUp.value = false
            }

        }
    }

    func updateInsertionPointColor() {
        // Removing the UITextSelectionView and re-adding it forces it to query the insertion point color.
        if let textSelectionView {
            let parentView = textSelectionView.superview
            textSelectionView.removeFromSuperview()
            parentView?.addSubview(textSelectionView)
        }
    }
}

private extension UITextSelectionViewManager {
    private var textSelectionView: UIView? {
        if let klass = NSClassFromString("UITextSelectionView") {
            return textView?.subviews.first { $0.isKind(of: klass) }
        } else {
            return nil
        }
    }

    private var caretView: UIView? {
        textSelectionView?.value(forKey: "m_caretView") as? UIView
    }

    private var floatingCaretView: UIView? {
        textSelectionView?.value(forKey: "m_floatingCaretView") as? UIView
    }

//    private func checkIfInsertionPointPickedUp() -> Bool {
//        guard let textSelectionView else {
//            return false
//        }
//        guard textSelectionView.subviews.count == 2 else {
//            return false
//        }
//        guard let textRangeViewClass = NSClassFromString("UITextRangeView") else {
//            return false
//        }
//        return !textSelectionView.subviews.contains(where: { $0.isKind(of: textRangeViewClass) })
//    }
}
#endif
