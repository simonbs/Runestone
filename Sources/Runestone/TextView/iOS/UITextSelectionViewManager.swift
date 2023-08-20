#if os(iOS)
import Combine
import UIKit

final class UITextSelectionViewManager {
    var containsCaret: Bool {
        caretView != nil
    }

    private weak var textView: TextView?
    private let floatingInsertionPointPosition: CurrentValueSubject<CGPoint?, Never>
    private var subviewsObserver: NSKeyValueObservation?
    private var floatingCaretViewPositionObserver: NSKeyValueObservation?
    private var caretViewHiddenObserver: NSKeyValueObservation?
    private var floatingCaretViewHiddenObserver: NSKeyValueObservation?
    private var cancellables: Set<AnyCancellable> = []
    private let insertionPointViewFactory: InsertionPointViewFactory
    private var customFloatingCaretView: UIView?
    private var insertionPointFrame: CGRect = .zero

    init(
        textView: CurrentValueSubject<WeakBox<TextView>, Never>,
        insertionPointFrame: AnyPublisher<CGRect, Never>,
        floatingInsertionPointPosition: CurrentValueSubject<CGPoint?, Never>,
        insertionPointViewFactory: InsertionPointViewFactory
    ) {
        self.floatingInsertionPointPosition = floatingInsertionPointPosition
        self.insertionPointViewFactory = insertionPointViewFactory
        textView.sink { [weak self] box in
            self?.textView = box.value
        }.store(in: &cancellables)
        insertionPointFrame.sink { [weak self] frame in
            self?.insertionPointFrame = frame
            if let center = self?.customFloatingCaretView?.center {
                self?.layoutFloatingInsertionPointView(ofSize: frame.size, centeredAt: center)
            }
        }.store(in: &cancellables)
    }

    func setupCaretViewObserver() {
        textSelectionView?.layer.zPosition = 5000
        let rootView = if #available(iOS 17, *) {
            textView
        } else {
            textSelectionView
        }
        // UIView.subviews isn't observable but CALayer.sublayers is. So we observe the CALayer's sublayers to detect changes in the cursor view hierarchy.
        subviewsObserver = rootView?.observe(\.layer.sublayers, options: .new) { [weak self] _, change in
            // Need to dispatch in order for the change to be reflected in the textSelectionView.subviews property.
            DispatchQueue.main.async { [weak self] in
                self?.hideDefaultCaretViews()
                self?.updateCustomFloatingCaretViewViewHiearachy()
                self?.setupFloatingCaretViewPositionObserver()
                self?.updateFloatingInsertionPointPosition()
                if let size = self?.insertionPointFrame.size, let center = self?.floatingCaretView?.center {
                    self?.layoutFloatingInsertionPointView(ofSize: size, centeredAt: center)
                }
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
        if #unavailable(iOS 17), let klass = NSClassFromString("UITextSelectionView") {
            return textView?.subviews.first { $0.isKind(of: klass) }
        } else {
            return nil
        }
    }

    private var caretView: UIView? {
        if #available(iOS 17, *), let klass = NSClassFromString("_UITextCursorView") {
            return textView?.subviews.first { $0.isKind(of: klass) }
        } else {
            return textSelectionView?.value(forKey: "m_caretView") as? UIView
        }
    }

    private var floatingCaretView: UIView? {
        if #available(iOS 17, *), let klass = NSClassFromString("_UITextCursorView") {
            let cursorViews = textView?.subviews.filter { $0.isKind(of: klass) } ?? []
            if cursorViews.count >= 2 {
                return cursorViews.last
            } else {
                return nil
            }
        } else {
            return textSelectionView?.value(forKey: "m_floatingCaretView") as? UIView
        }
    }

    private func setupFloatingCaretViewPositionObserver() {
        floatingCaretViewPositionObserver = floatingCaretView?.observe(\.center, options: .new) { [weak self] _, change in
            if let center = change.newValue, let size = self?.customFloatingCaretView?.frame.size {
                self?.updateFloatingInsertionPointPosition()
                self?.layoutFloatingInsertionPointView(ofSize: size, centeredAt: center)
            }
        }
    }

    private func updateFloatingInsertionPointPosition() {
        if floatingCaretView?.superview != nil {
            floatingInsertionPointPosition.value = floatingCaretView?.center
        } else {
            floatingInsertionPointPosition.value = nil
        }
    }

    private func hideDefaultCaretViews() {
        caretView?.isHidden = true
        floatingCaretView?.isHidden = true
        caretViewHiddenObserver = caretView?.observe(\.isHidden) { [weak self] _, _ in
            if let caretView = self?.caretView, !caretView.isHidden {
                caretView.isHidden = true
            }
        }
        floatingCaretViewHiddenObserver = floatingCaretView?.observe(\.isHidden) { [weak self] _, _ in
            if let floatingCaretView = self?.floatingCaretView, !floatingCaretView.isHidden {
                floatingCaretView.isHidden = true
            }
        }
    }

    private func updateCustomFloatingCaretViewViewHiearachy() {
        if floatingCaretView?.superview == nil {
            customFloatingCaretView?.removeFromSuperview()
            customFloatingCaretView = nil
        } else {
            let customFloatingCaretView = makeCustomfloatingCaretViewIfNeeded()
            if customFloatingCaretView.superview == nil {
                if #available(iOS 17, *) {
                    textView?.addSubview(customFloatingCaretView)
                } else {
                    textSelectionView?.addSubview(customFloatingCaretView)
                }
            }
        }
    }

    private func layoutFloatingInsertionPointView(ofSize size: CGSize, centeredAt center: CGPoint) {
        let origin = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
        customFloatingCaretView?.frame = CGRect(origin: origin, size: size)
    }

    private func makeCustomfloatingCaretViewIfNeeded() -> UIView {
        if let customFloatingCaretView {
            return customFloatingCaretView
        } else {
            let customFloatingCaretView = insertionPointViewFactory.makeView()
            customFloatingCaretView.isFloating = true
            customFloatingCaretView.layer.zPosition = 5000
            self.customFloatingCaretView = customFloatingCaretView
            return customFloatingCaretView
        }
    }
}
#endif
