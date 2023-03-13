import Combine
import CoreGraphics

final class Caret {
    #if os(iOS)
    static let width: CGFloat = 2
    #else
    static let width: CGFloat = 1
    #endif

    let frame = CurrentValueSubject<CGRect, Never>(.zero)

    private let stringView: CurrentValueSubject<StringView, Never>
    private let lineManager: CurrentValueSubject<LineManager, Never>
    private let lineControllerStorage: LineControllerStorage
    private let contentArea: CurrentValueSubject<CGRect, Never>
    private var cancellables: Set<AnyCancellable> = []

    init(
        stringView: CurrentValueSubject<StringView, Never>,
        lineManager: CurrentValueSubject<LineManager, Never>,
        lineControllerStorage: LineControllerStorage,
        contentArea: CurrentValueSubject<CGRect, Never>,
        location: AnyPublisher<Int, Never>
    ) {
        self.stringView = stringView
        self.lineManager = lineManager
        self.lineControllerStorage = lineControllerStorage
        self.contentArea = contentArea
        setupCurrentFrameUpdater(location: location)
    }

    func frame(at location: Int, allowMovingCaretToNextLineFragment: Bool) -> CGRect {
        let calculator = Calculator(
            stringView: stringView.value,
            lineManager: lineManager.value,
            lineControllerStorage: lineControllerStorage,
            contentArea: contentArea.value
        )
        return calculator.frame(at: location, allowMovingCaretToNextLineFragment: allowMovingCaretToNextLineFragment)
    }
}

private extension Caret {
    private func setupCurrentFrameUpdater(location: AnyPublisher<Int, Never>) {
        Publishers.CombineLatest4(
            stringView,
            lineManager,
            contentArea,
            location
        ).map { [unowned self] stringView, lineManager, contentArea, location in
            let calculator = Calculator(
                stringView: stringView,
                lineManager: lineManager,
                lineControllerStorage: lineControllerStorage,
                contentArea: contentArea
            )
            return calculator.frame(at: location, allowMovingCaretToNextLineFragment: true)
        }.removeDuplicates().sink { [weak self] frame in
            self?.frame.value = frame
        }.store(in: &cancellables)
    }
}

private extension Caret {
    private struct Calculator {
        let stringView: StringView
        let lineManager: LineManager
        let lineControllerStorage: LineControllerStorage
        let contentArea: CGRect

        func frame(at location: Int, allowMovingCaretToNextLineFragment: Bool) -> CGRect {
            let safeLocation = min(max(location, 0), stringView.string.length)
            let line = lineManager.line(containingCharacterAt: safeLocation)!
            let lineController = lineControllerStorage.getOrCreateLineController(for: line)
            let lineLocalLocation = safeLocation - line.location
            if allowMovingCaretToNextLineFragment && shouldMoveCaretToNextLineFragment(forLocation: lineLocalLocation, in: line) {
                let rect = frame(at: location + 1, allowMovingCaretToNextLineFragment: false)
                return CGRect(x: contentArea.minX, y: rect.minY, width: rect.width, height: rect.height)
            } else {
                let localCaretRect = lineController.caretRect(atIndex: lineLocalLocation)
                let globalYPosition = line.yPosition + localCaretRect.minY
                let globalRect = CGRect(x: localCaretRect.minX, y: globalYPosition, width: localCaretRect.width, height: localCaretRect.height)
                return globalRect.offsetBy(dx: contentArea.minX, dy: contentArea.minY)
            }
        }

        private func shouldMoveCaretToNextLineFragment(forLocation location: Int, in line: LineNode) -> Bool {
            let lineController = lineControllerStorage.getOrCreateLineController(for: line)
            guard lineController.numberOfLineFragments > 0 else {
                return false
            }
            guard let lineFragmentNode = lineController.lineFragmentNode(containingCharacterAt: location) else {
                return false
            }
            guard lineFragmentNode.index > 0 else {
                return false
            }
            return location == lineFragmentNode.data.lineFragment?.range.location
        }
    }
}
