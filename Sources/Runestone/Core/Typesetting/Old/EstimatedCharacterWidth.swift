//import _RunestoneMultiPlatform
//import Combine
//import CoreText
//import Foundation
//
//final class EstimatedCharacterWidth {
//    let rawValue: CurrentValueSubject<CGFloat, Never>
//
//    private var cancellables: Set<AnyCancellable> = []
//
//    init(font: CurrentValueSubject<MultiPlatformFont, Never>) {
//        rawValue = CurrentValueSubject(Self.estimatedWidth(using: font.value))
//        font.sink { [weak self] font in
//            self?.rawValue.value = Self.estimatedWidth(using: font)
//        }.store(in: &cancellables)
//    }
//}
//
//private extension EstimatedCharacterWidth {
//    private static func estimatedWidth(using font: MultiPlatformFont) -> CGFloat {
//        ("8" as NSString).size(withAttributes: [.font: font]).width
//    }
//}
