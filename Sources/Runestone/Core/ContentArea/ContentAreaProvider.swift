import Combine
import CoreGraphics

final class ContentAreaProvider {
    var contentArea: CGRect {
        let textContainerInset = textContainerInset.value
        let width = max(viewport.value.width, contentSize.value.width)
//        - textContainerInset.left
//        - textContainerInset.right
        let height = max(viewport.value.height, contentSize.value.height)
//        - textContainerInset.top
//        - textContainerInset.bottom
        return CGRect(x: textContainerInset.left, y: textContainerInset.top, width: width, height: height)
    }

    private unowned let viewport: CurrentValueSubject<CGRect, Never>
    private unowned let contentSize: CurrentValueSubject<CGSize, Never>
    private unowned let textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>

    init(
        viewport: CurrentValueSubject<CGRect, Never>,
        contentSize: CurrentValueSubject<CGSize, Never>,
        textContainerInset: CurrentValueSubject<MultiPlatformEdgeInsets, Never>
    ) {
        self.viewport = viewport
        self.contentSize = contentSize
        self.textContainerInset = textContainerInset
    }
}
