import Combine
import Foundation
#if os(iOS)
import UIKit
#endif

final class InsertionPointLayouter {
    private let view: InsertionPointView
    private var cancellabels: Set<AnyCancellable> = []

    init(
        insertionPointViewFactory: InsertionPointViewFactory,
        frame: AnyPublisher<CGRect, Never>,
        containerView: CurrentValueSubject<WeakBox<TextView>, Never>,
        isInsertionPointVisible: AnyPublisher<Bool, Never>,
        isInsertionPointBeingMoved: AnyPublisher<Bool, Never>
    ) {
        view = insertionPointViewFactory.makeView()
        #if os(iOS)
        view.layer.zPosition = 1000
        #else
        view.layer?.zPosition = 1000
        #endif
        view.isHidden = true
        isInsertionPointVisible.sink { [weak self] isInsertionPointVisible in
            if isInsertionPointVisible {
                self?.view.isHidden = false
                self?.view.delayBlink()
            } else {
                self?.view.isHidden = true
            }
        }.store(in: &cancellabels)
        Publishers.CombineLatest(isInsertionPointVisible, isInsertionPointBeingMoved)
            .map { $0 && !$1 }
            .removeDuplicates()
            .sink { [weak self] isBlinkingEnabled in
                self?.view.isBlinkingEnabled = isBlinkingEnabled
            }.store(in: &cancellabels)
        containerView.sink { [weak self] box in
            if let self {
                self.view.removeFromSuperview()
                box.value?.addSubview(self.view)
            }
        }.store(in: &cancellabels)
        frame.sink { [weak self] frame in
            self?.view.frame = frame
        }.store(in: &cancellabels)
    }
}
