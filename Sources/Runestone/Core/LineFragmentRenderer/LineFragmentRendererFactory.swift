import Combine
import Foundation

struct LineFragmentRendererFactory {
    let stringView: CurrentValueSubject<StringView, Never>
    let showInvisibleCharacters: CurrentValueSubject<Bool, Never>
    let invisibleCharacterRenderer: InvisibleCharacterRenderer

    func makeRenderer(for lineFragment: LineFragment, in line: LineNode) -> LineFragmentRenderer {
        CompositeLineFragmentRenderer(renderers: [
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
