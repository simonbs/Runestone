#if os(macOS)
import AppKit
#endif
import Combine
import Foundation
#if os(iOS)
import UIKit
#endif

struct InvisibleCharactersLineFragmentRenderer: LineFragmentRendering {
    let showInvisibleCharacters: CurrentValueSubject<Bool, Never>
    let invisibleCharacterRenderer: InvisibleCharacterRenderer
    
    func render<LineType: Line>(
        _ lineFragment: LineType.LineFragmentType,
        in line: LineType,
        to context: CGContext
    ) {
        guard showInvisibleCharacters.value else {
            return
        }
        let range = NSRange(
            location: line.location + lineFragment.visibleRange.location,
            length: lineFragment.visibleRange.length
        )
        for location in range.lowerBound ..< range.upperBound {
            invisibleCharacterRenderer.renderInvisibleCharacter(
                atLocation: location,
                alignedTo: lineFragment,
                in: line
            )
        }
    }
}
