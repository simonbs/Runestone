import Combine
import CoreGraphics

final class EstimatedLineHeight {
    private(set) var rawValue: CGFloat

    private var cancellables: Set<AnyCancellable> = []

    init(font: AnyPublisher<MultiPlatformFont, Never>, lineHeightMultiplier: AnyPublisher<CGFloat, Never>) {
        Publishers.CombineLatest(font, lineHeightMultiplier).sink { [weak self] font, lineHeightMultiplier in
            self?.rawValue = font.totalLineHeight * lineHeightMultiplier
        }.store(in: &cancellables)
    }
}
