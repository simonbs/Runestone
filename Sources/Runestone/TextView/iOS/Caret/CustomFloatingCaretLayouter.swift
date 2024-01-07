//#if os(iOS)
//import Combine
//import UIKit
//
//final class CustomFloatingCaretLayouter {
//    private let caretParentViewProvider: StandardCaretParentViewProvider
//    private let floatingCaretViewProvider: StandardFloatingCaretViewProvider
//    private let floatingInsertionPointPosition: CurrentValueSubject<CGPoint?, Never>
//    private var subviewsObserver: NSKeyValueObservation?
//    private var floatingCaretViewPositionObserver: NSKeyValueObservation?
//    private let insertionPointViewFactory: InsertionPointViewFactory
//    private var insertionPointFrame: CGRect = .zero
//    private var customFloatingCaretView: UIView?
//    private var cancellables: Set<AnyCancellable> = []
//    private var caretParentView: UIView? {
//        caretParentViewProvider.parentView
//    }
//    private var floatingCaretView: UIView? {
//        floatingCaretViewProvider.floatingCaretView
//    }
//
//    init(
//        caretParentViewProvider: StandardCaretParentViewProvider,
//        floatingCaretViewProvider: StandardFloatingCaretViewProvider,
//        insertionPointFrame: AnyPublisher<CGRect, Never>,
//        floatingInsertionPointPosition: CurrentValueSubject<CGPoint?, Never>,
//        insertionPointViewFactory: InsertionPointViewFactory
//    ) {
//        self.floatingInsertionPointPosition = floatingInsertionPointPosition
//        self.insertionPointViewFactory = insertionPointViewFactory
//        self.caretParentViewProvider = caretParentViewProvider
//        self.floatingCaretViewProvider = floatingCaretViewProvider
//        insertionPointFrame.sink { [weak self] frame in
//            self?.insertionPointFrame = frame
//            if let center = self?.customFloatingCaretView?.center {
//                self?.layoutFloatingInsertionPointView(ofSize: frame.size, centeredAt: center)
//            }
//        }.store(in: &cancellables)
//    }
//
//    func setupFloatingCaretViewObserver() {
//        subviewsObserver = caretParentView?.observe(\.layer.sublayers, options: .new) { [weak self] _, change in
//            DispatchQueue.main.async { [weak self] in
//                if self?.floatingCaretView?.superview == nil {
//                    self?.removeCustomFloatingCaretViewFromViewHierarchy()
//                } else {
//                    self?.addCustomFloatingCaretViewIntoViewHierarchy()
//                }
//                self?.setupFloatingCaretViewPositionObserver()
//                self?.updateFloatingInsertionPointPosition()
//                if let size = self?.insertionPointFrame.size, let center = self?.floatingCaretView?.center {
//                    self?.layoutFloatingInsertionPointView(ofSize: size, centeredAt: center)
//                }
//            }
//        }
//    }
//}
//
//private extension CustomFloatingCaretLayouter {
//    private func setupFloatingCaretViewPositionObserver() {
//        floatingCaretViewPositionObserver = floatingCaretView?.observe(\.center, options: .new) { [weak self] _, change in
//            if let center = change.newValue, let size = self?.customFloatingCaretView?.frame.size {
//                self?.updateFloatingInsertionPointPosition()
//                self?.layoutFloatingInsertionPointView(ofSize: size, centeredAt: center)
//            }
//        }
//    }
//
//    private func updateFloatingInsertionPointPosition() {
//        if floatingCaretView?.superview != nil {
//            floatingInsertionPointPosition.value = floatingCaretView?.center
//        } else {
//            floatingInsertionPointPosition.value = nil
//        }
//    }
//
//    private func removeCustomFloatingCaretViewFromViewHierarchy() {
//        customFloatingCaretView?.removeFromSuperview()
//        customFloatingCaretView = nil
//    }
//
//    private func addCustomFloatingCaretViewIntoViewHierarchy() {
//        let customFloatingCaretView = makeCustomfloatingCaretViewIfNeeded()
//        if customFloatingCaretView.superview == nil {
//            caretParentView?.addSubview(customFloatingCaretView)
//        }
//    }
//
//    private func layoutFloatingInsertionPointView(ofSize size: CGSize, centeredAt center: CGPoint) {
//        let origin = CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2)
//        customFloatingCaretView?.frame = CGRect(origin: origin, size: size)
//    }
//
//    private func makeCustomfloatingCaretViewIfNeeded() -> UIView {
//        if let customFloatingCaretView {
//            return customFloatingCaretView
//        } else {
//            let customFloatingCaretView = insertionPointViewFactory.makeView()
//            customFloatingCaretView.isFloating = true
//            customFloatingCaretView.layer.zPosition = 5000
//            self.customFloatingCaretView = customFloatingCaretView
//            return customFloatingCaretView
//        }
//    }
//}
//#endif
