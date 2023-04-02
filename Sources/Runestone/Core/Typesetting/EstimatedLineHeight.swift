import Combine
import CoreGraphics

final class EstimatedLineHeight {
    private(set) var value: CGFloat = 10
    private(set) var scaledValue: CGFloat = 10

    private var cancellables: Set<AnyCancellable> = []

    init(font: AnyPublisher<MultiPlatformFont, Never>, lineHeightMultiplier: AnyPublisher<CGFloat, Never>) {
        Publishers.CombineLatest(font, lineHeightMultiplier).sink { [weak self] font, lineHeightMultiplier in
            self?.value = font.actualLineHeight
            self?.scaledValue = font.actualLineHeight * lineHeightMultiplier
        }.store(in: &cancellables)
    }
}
