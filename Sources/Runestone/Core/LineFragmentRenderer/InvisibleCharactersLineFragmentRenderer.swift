#if os(macOS)
import AppKit
#endif
import Combine
import Foundation
#if os(iOS)
import UIKit
#endif

final class InvisibleCharactersLineFragmentRenderer<LineType: Line>: LineFragmentRenderer {
    private let line: LineType
    private let lineFragment: LineType.LineFragmentType
    private let showInvisibleCharacters: CurrentValueSubject<Bool, Never>
    private let invisibleCharacterRenderer: InvisibleCharacterRenderer

    init(
        line: LineType,
        lineFragment: LineType.LineFragmentType,
        showInvisibleCharacters: CurrentValueSubject<Bool, Never>,
        invisibleCharacterRenderer: InvisibleCharacterRenderer
    ) {
        self.line = line
        self.lineFragment = lineFragment
        self.showInvisibleCharacters = showInvisibleCharacters
        self.invisibleCharacterRenderer = invisibleCharacterRenderer
    }

    func render() {
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
