import Combine
import CoreGraphics

struct ContentAreaPublisherFactory {
    let viewport: CurrentValueSubject<CGRect, Never>
    let contentSize: CurrentValueSubject<CGSize, Never>
    let textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>

    func makePublisher() -> AnyPublisher<CGRect, Never> {
        Publishers.CombineLatest3(
            viewport,
            contentSize,
            textContainerInset
        ).map { viewport, contentSize, textContainerInset in
            let width = max(viewport.width, contentSize.width) - textContainerInset.left - textContainerInset.right
            let height = max(viewport.height, contentSize.height) - textContainerInset.top - textContainerInset.bottom
            return CGRect(x: textContainerInset.left, y: textContainerInset.top, width: width, height: height)
        }.eraseToAnyPublisher()
    }
}
