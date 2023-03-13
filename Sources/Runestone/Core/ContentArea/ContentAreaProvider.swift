import Combine
import CoreGraphics

final class ContentArea {
    let rawValue = CurrentValueSubject<CGRect, Never>(.zero)

    private var cancellables = Set<AnyCancellable>()

    init(
        viewport: CurrentValueSubject<CGRect, Never>,
        contentSize: CurrentValueSubject<CGSize, Never>,
        textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>
    ) {
        Publishers.CombineLatest3(
            viewport,
            contentSize,
            textContainerInset
        ).sink { [weak self] viewport, contentSize, textContainerInset in
            guard let self else {
                return
            }
            let width = max(viewport.width, contentSize.width) - textContainerInset.left - textContainerInset.right
            let height = max(viewport.height, contentSize.height) - textContainerInset.top - textContainerInset.bottom
            self.rawValue.value = CGRect(x: textContainerInset.left, y: textContainerInset.top, width: width, height: height)
        }.store(in: &cancellables)
    }
}
