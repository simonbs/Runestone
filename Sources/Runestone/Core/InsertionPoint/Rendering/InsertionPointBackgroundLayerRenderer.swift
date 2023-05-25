import Combine
import CoreGraphics
#if os(iOS)
import UIKit
#endif

final class InsertionPointBackgroundRenderer: InsertionPointRenderer {
    let needsRender: AnyPublisher<Bool, Never>

    private let insertionPointShape: CurrentValueSubject<InsertionPointShape, Never>
    private let insertionPointBackgroundColor: CurrentValueSubject<MultiPlatformColor, Never>
    private let textViewBackgroundColor: CurrentValueSubject<MultiPlatformColor?, Never>
    private let _needsRender = CurrentValueSubject<Bool, Never>(false)
    private var cancellables: Set<AnyCancellable> = []
    private var isInsertionPointBeingMoved = false {
        didSet {
            if isInsertionPointBeingMoved != oldValue {
                _needsRender.value = true
            }
        }
    }

    init(
        insertionPointShape: CurrentValueSubject<InsertionPointShape, Never>,
        isInsertionPointBeingMoved: AnyPublisher<Bool, Never>,
        insertionPointBackgroundColor: CurrentValueSubject<MultiPlatformColor, Never>,
        textViewBackgroundColor: CurrentValueSubject<MultiPlatformColor?, Never>
    ) {
        self.insertionPointShape = insertionPointShape
        self.insertionPointBackgroundColor = insertionPointBackgroundColor
        self.textViewBackgroundColor = textViewBackgroundColor
        self.needsRender = _needsRender.eraseToAnyPublisher()
        isInsertionPointBeingMoved.sink { [weak self] isInsertionPointBeingMoved in
            self?.isInsertionPointBeingMoved = isInsertionPointBeingMoved
        }.store(in: &cancellables)
        Publishers.CombineLatest(
            insertionPointBackgroundColor, textViewBackgroundColor
        ).sink { [weak self] _, _ in
            self?._needsRender.value = true
        }.store(in: &cancellables)
    }

    func render(_ rect: CGRect, to context: CGContext) {
        defer {
            _needsRender.value = false
        }
        var colors = [insertionPointBackgroundColor.value.cgColor]
        if isInsertionPointBeingMoved, let textViewBackgroundColor = textViewBackgroundColor.value {
            colors.append(textViewBackgroundColor.withAlphaComponent(0.5).cgColor)
        }
        context.saveGState()
        for color in colors {
            context.setFillColor(color)
            switch insertionPointShape.value {
            case .verticalBar:
                let path = UIBezierPath(roundedRect: rect, cornerRadius: rect.width / 2)
                context.addPath(path.cgPath)
                context.fillPath()
            case .underline:
                let path = UIBezierPath(roundedRect: rect, cornerRadius: rect.height / 2)
                context.addPath(path.cgPath)
                context.fillPath()
            case .block:
                context.fill(rect)
            }
        }
        context.restoreGState()
    }
}
