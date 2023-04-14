import Combine
import Foundation

struct LineFragmentRendererFactory {
    let stringView: CurrentValueSubject<StringView, Never>
    let invisibleCharacterSettings: InvisibleCharacterSettings
    let invisibleCharacterRenderer: InvisibleCharacterRenderer

    func makeRenderer(for lineFragment: LineFragment, in line: LineNode) -> LineFragmentRenderer {
        CompositeLineFragmentRenderer(renderers: [
            InvisibleCharactersLineFragmentRenderer(
                line: line,
                lineFragment: lineFragment,
                invisibleCharacterSettings: invisibleCharacterSettings,
                invisibleCharacterRenderer: invisibleCharacterRenderer
            ),
            TextLineFragmentRenderer(lineFragment: lineFragment)
        ])
    }
}
