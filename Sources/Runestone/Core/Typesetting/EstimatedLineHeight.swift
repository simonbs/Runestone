import _RunestoneMultiPlatform
import Combine
import CoreGraphics

final class EstimatedLineHeight {
    let rawValue = CurrentValueSubject<CGFloat, Never>(0)
    let scaledValue = CurrentValueSubject<CGFloat, Never>(0)

    private var cancellables: Set<AnyCancellable> = []

    init(
        font: AnyPublisher<MultiPlatformFont, Never>,
        lineHeightMultiplier: AnyPublisher<CGFloat, Never>
    ) {
        Publishers.CombineLatest(font, lineHeightMultiplier).sink { [weak self] font, lineHeightMultiplier in
            self?.rawValue.value = font.actualLineHeight
            self?.scaledValue.value = font.actualLineHeight * lineHeightMultiplier
        }.store(in: &cancellables)
    }
}
