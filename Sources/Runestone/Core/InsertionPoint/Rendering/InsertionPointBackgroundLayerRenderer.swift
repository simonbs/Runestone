import _RunestoneMultiPlatform
import Combine
import CoreGraphics

final class InsertionPointBackgroundRenderer: InsertionPointRenderer {
    let needsRender: AnyPublisher<Bool, Never>

    private let insertionPointShape: CurrentValueSubject<InsertionPointShape, Never>
    private let insertionPointBackgroundColor: CurrentValueSubject<MultiPlatformColor, Never>
    private let insertionPointPlaceholderBackgroundColor: CurrentValueSubject<MultiPlatformColor, Never>
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
        insertionPointPlaceholderBackgroundColor: CurrentValueSubject<MultiPlatformColor, Never>,
        textViewBackgroundColor: CurrentValueSubject<MultiPlatformColor?, Never>
    ) {
        self.insertionPointShape = insertionPointShape
        self.insertionPointBackgroundColor = insertionPointBackgroundColor
        self.insertionPointPlaceholderBackgroundColor = insertionPointPlaceholderBackgroundColor
        self.textViewBackgroundColor = textViewBackgroundColor
        self.needsRender = _needsRender.eraseToAnyPublisher()
        isInsertionPointBeingMoved.sink { [weak self] isInsertionPointBeingMoved in
            self?.isInsertionPointBeingMoved = isInsertionPointBeingMoved
        }.store(in: &cancellables)
        Publishers.CombineLatest(
            insertionPointBackgroundColor.removeDuplicates(),
            insertionPointPlaceholderBackgroundColor.removeDuplicates()
        ).sink { [weak self] _, _ in
            self?._needsRender.value = true
        }.store(in: &cancellables)
    }

    func render(_ rect: CGRect, to context: CGContext) {
        defer {
            _needsRender.value = false
        }
        let textViewBackgroundColor = textViewBackgroundColor.value ?? .textBackgroundColor
        let color = isInsertionPointBeingMoved ? insertionPointPlaceholderBackgroundColor.value : insertionPointBackgroundColor.value
        context.saveGState()
        context.setFillColor(textViewBackgroundColor.cgColor)
        context.fill([rect])
        context.setFillColor(color.cgColor)
        switch insertionPointShape.value {
        case .verticalBar:
            let path = CGPath(roundedRect: rect, cornerWidth: rect.width / 2, cornerHeight: rect.width / 2, transform: nil)
            context.addPath(path)
            context.fillPath()
        case .underline:
            let path = CGPath(roundedRect: rect, cornerWidth: rect.height / 2, cornerHeight: rect.height / 2, transform: nil)
            context.addPath(path)
            context.fillPath()
        case .block:
            context.fill(rect)
        }
        context.restoreGState()
    }
}
