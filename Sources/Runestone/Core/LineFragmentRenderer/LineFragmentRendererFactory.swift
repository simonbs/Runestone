import Combine
import Foundation

struct LineFragmentRendererFactory {
    let stringView: CurrentValueSubject<StringView, Never>
    let showInvisibleCharacters: CurrentValueSubject<Bool, Never>
    let invisibleCharacterRenderer: InvisibleCharacterRenderer
    let markedRange: CurrentValueSubject<NSRange?, Never>
    let inlinePredictionRange: CurrentValueSubject<NSRange?, Never>
    let markedTextBackgroundColor: CurrentValueSubject<MultiPlatformColor, Never>
    let markedTextBackgroundCornerRadius: CurrentValueSubject<CGFloat, Never>

    func makeRenderer(for lineFragment: LineFragment, in line: LineNode) -> LineFragmentRenderer {
        CompositeLineFragmentRenderer(renderers: [
            MarkedRangeLineFragmentRenderer(
                lineFragment: lineFragment,
                markedRange: markedRange,
                inlinePredictionRange: inlinePredictionRange,
                backgroundColor: markedTextBackgroundColor,
                backgroundCornerRadius: markedTextBackgroundCornerRadius
            ),
            InvisibleCharactersLineFragmentRenderer(
                line: line,
                lineFragment: lineFragment,
                showInvisibleCharacters: showInvisibleCharacters,
                invisibleCharacterRenderer: invisibleCharacterRenderer
            ),
            TextLineFragmentRenderer(lineFragment: lineFragment)
        ])
    }
}
