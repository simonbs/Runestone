import Combine
import Foundation

struct RendererFactory {
    let stringView: CurrentValueSubject<StringView, Never>
    let invisibleCharacterSettings: InvisibleCharacterSettings

    func makeRenderer(for lineFragment: LineFragment, in line: LineNode) -> Renderer {
        CompositeRenderer(renderers: [
            InvisibleCharactersRenderer(
                lineFragment: lineFragment,
                stringProvider: RendererStringProvider(
                    stringView: stringView,
                    line: line,
                    lineFragment: lineFragment
                ),
                invisibleCharacterSettings: invisibleCharacterSettings
            ),
            TextRenderer(lineFragment: lineFragment)
        ])
    }
}
