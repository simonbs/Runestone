//import Combine
//import CoreText
//import Foundation
//
//struct InsertionPointFramePublisherFactory {
//    let insertionPointFrameFactory: InsertionPointFrameFactory
//    let selectedRange: AnyPublisher<NSRange, Never>
//    let insertionPointShape: AnyPublisher<InsertionPointShape, Never>
//    let contentArea: AnyPublisher<CGRect, Never>
//    let estimatedLineHeight: EstimatedLineHeight
//    let estimatedCharacterWidth: AnyPublisher<CGFloat, Never>
//    let kern: AnyPublisher<CGFloat, Never>
//
//    func makeFramePublisher() -> AnyPublisher<CGRect, Never> {
//        Publishers.CombineLatest3(
//            selectedRange,
//            Publishers.CombineLatest3(
//                contentArea,
//                insertionPointShape,
//                kern
//            ),
//            Publishers.CombineLatest3(
//                estimatedLineHeight.rawValue,
//                estimatedLineHeight.scaledValue,
//                estimatedCharacterWidth
//            )
//        ).map { selectedRange, _, _ in
//            insertionPointFrameFactory.frameOfInsertionPoint(at: selectedRange.location)
//        }.eraseToAnyPublisher()
//    }
//}
