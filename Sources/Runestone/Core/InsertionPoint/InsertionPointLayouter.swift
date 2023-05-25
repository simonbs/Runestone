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
        selectedRange: AnyPublisher<NSRange, Never>,
        isKeyWindow: AnyPublisher<Bool, Never>,
        isFirstResponder: AnyPublisher<Bool, Never>,
        isInsertionPointBeingMoved: AnyPublisher<Bool, Never>
    ) {
        view = insertionPointViewFactory.makeView()
        #if os(iOS)
        view.layer.zPosition = 1000
        #else
        view.layer?.zPosition = 1000
        #endif
        view.isHidden = true
        selectedRange.removeDuplicates().sink { [weak self] _ in
            self?.view.delayBlink()
        }.store(in: &cancellabels)
        let isInsertionPointShown = Publishers.CombineLatest3(
            isKeyWindow,
            isFirstResponder,
            selectedRange
        ).map { isKeyWindow, isFirstResponder, selectedRange in
            #if os(iOS)
            isFirstResponder && selectedRange.length == 0
            #else
            isKeyWindow && isFirstResponder && selectedRange.length == 0
            #endif
        }
        isInsertionPointShown.sink { [weak self] isInsertionPointShown in
            if isInsertionPointShown {
                self?.view.isHidden = false
                self?.view.delayBlink()
            } else {
                self?.view.isHidden = true
            }
        }.store(in: &cancellabels)
        Publishers.CombineLatest(isInsertionPointShown, isInsertionPointBeingMoved)
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
