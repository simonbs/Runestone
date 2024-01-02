import Combine
import Foundation

struct LineFragmentRendererFactory<LineFragmentType: LineFragment> {
//    let stringView: any StringView
//    let showInvisibleCharacters: CurrentValueSubject<Bool, Never>
//    let invisibleCharacterRenderer: InvisibleCharacterRenderer
//    let markedRange: CurrentValueSubject<NSRange?, Never>
//    let inlinePredictionRange: CurrentValueSubject<NSRange?, Never>
//    let markedTextBackgroundColor: CurrentValueSubject<MultiPlatformColor, Never>
//    let markedTextBackgroundCornerRadius: CurrentValueSubject<CGFloat, Never>

    func makeRenderer(for lineFragment: LineFragmentType, in line: LineNode) -> LineFragmentRenderer {
        fatalError("Not implemented")
//        CompositeLineFragmentRenderer(renderers: [
//            MarkedRangeLineFragmentRenderer(
//                lineFragment: lineFragment,
//                markedRange: markedRange,
//                inlinePredictionRange: inlinePredictionRange,
//                backgroundColor: markedTextBackgroundColor,
//                backgroundCornerRadius: markedTextBackgroundCornerRadius
//            ),
//            InvisibleCharactersLineFragmentRenderer(
//                line: line,
//                lineFragment: lineFragment,
//                showInvisibleCharacters: showInvisibleCharacters,
//                invisibleCharacterRenderer: invisibleCharacterRenderer
//            ),
//            TextLineFragmentRenderer(lineFragment: lineFragment)
//        ])
    }
}
