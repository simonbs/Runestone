#if os(macOS)
import AppKit
#endif
import Combine
import Foundation
#if os(iOS)
import UIKit
#endif

struct InvisibleCharactersLineFragmentRenderer<
    State: InvisibleCharacterConfigurationReadable & Equatable,
    InvisibleCharacterRendererType: InvisibleCharacterRendering & Equatable
>: LineFragmentRendering {
    let state: State
    let invisibleCharacterRenderer: InvisibleCharacterRendererType

    func render<LineType: Line>(
        _ lineFragment: LineType.LineFragmentType,
        in line: LineType,
        to context: CGContext
    ) {
        guard state.showInvisibleCharacters else {
            return
        }
        let location = line.location + lineFragment.visibleRange.location
        let length = lineFragment.visibleRange.length
        let range = NSRange(location: location, length: length)
        for location in range.lowerBound ..< range.upperBound {
            invisibleCharacterRenderer.renderInvisibleCharacter(
                atLocation: location,
                alignedTo: lineFragment,
                in: line
            )
        }
    }
}
