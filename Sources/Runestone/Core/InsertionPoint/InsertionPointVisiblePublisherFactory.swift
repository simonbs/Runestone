import CoreGraphics
import Combine
import Foundation

struct InsertionPointVisiblePublisherFactory {
    let selectedRange: AnyPublisher<NSRange, Never>
    let isKeyWindow: AnyPublisher<Bool, Never>
    let isFirstResponder: AnyPublisher<Bool, Never>
    let insertionPointVisibilityMode: AnyPublisher<InsertionPointVisibilityMode, Never>
    let floatingInsertionPointPosition: AnyPublisher<CGPoint?, Never>
    let insertionPointFrame: AnyPublisher<CGRect, Never>

    private var focusAllowsInsertionPointVisible: AnyPublisher<Bool, Never> {
        Publishers.CombineLatest(isKeyWindow, isFirstResponder).map { isKeyWindow, isFirstResponder in
            #if os(iOS)
            isFirstResponder
            #else
            isKeyWindow && isFirstResponder
            #endif
        }.eraseToAnyPublisher()
    }

    private var movementAllowsInsertionPointVisible: AnyPublisher<Bool, Never> {
        Publishers.CombineLatest3(
            insertionPointVisibilityMode,
            floatingInsertionPointPosition,
            insertionPointFrame
        ).map { insertionPointVisibilityMode, floatingInsertionPointPosition, insertionPointFrame in
            guard let floatingInsertionPointPosition else {
                // The insertion point is not being moved so we allow it to be visible.
                return true
            }
            switch insertionPointVisibilityMode {
            case .always:
                return true
            case .hiddenWhenMovingUnlessFarAway:
                let insertionPointCenter = CGPoint(x: insertionPointFrame.midX, y: insertionPointFrame.midY)
                let distance = insertionPointCenter.distance(to: floatingInsertionPointPosition)
                return distance >= 15
            }
        }.eraseToAnyPublisher()
    }

    func makePublisher() -> AnyPublisher<Bool, Never> {
        Publishers.CombineLatest3(
            focusAllowsInsertionPointVisible,
            movementAllowsInsertionPointVisible,
            selectedRange
        ).map { focusAllowsInsertionPointVisible, movementAllowsInsertionPointVisible, selectedRange in
            focusAllowsInsertionPointVisible && movementAllowsInsertionPointVisible && selectedRange.length == 0
        }.eraseToAnyPublisher()
    }
}

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        sqrt(pow(x - other.x, 2) + pow(y - other.y, 2))
    }
}
