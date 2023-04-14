import Combine
import CoreGraphics

struct TextContainer {
    let viewport = CurrentValueSubject<CGRect, Never>(.zero)
    let inset = CurrentValueSubject<MultiPlatformEdgeInsets, Never>(.zero)
    let safeAreaInsets = CurrentValueSubject<MultiPlatformEdgeInsets, Never>(.zero)
}
