#if os(macOS)
import AppKit
#endif
import Foundation
#if os(iOS)
import UIKit
#endif

final class InvisibleCharactersLineFragmentRenderer: LineFragmentRenderer {
    private let line: LineNode
    private let lineFragment: LineFragment
    private let invisibleCharacterSettings: InvisibleCharacterSettings
    private let invisibleCharacterRenderer: InvisibleCharacterRenderer

    init(
        line: LineNode,
        lineFragment: LineFragment,
        invisibleCharacterSettings: InvisibleCharacterSettings,
        invisibleCharacterRenderer: InvisibleCharacterRenderer
    ) {
        self.line = line
        self.lineFragment = lineFragment
        self.invisibleCharacterSettings = invisibleCharacterSettings
        self.invisibleCharacterRenderer = invisibleCharacterRenderer
    }

    func render() {
        guard invisibleCharacterSettings.showInvisibleCharacters.value else {
            return
        }
        let range = NSRange(location: line.location + lineFragment.visibleRange.location, length: lineFragment.visibleRange.length)
        for location in range.lowerBound ..< range.upperBound {
            invisibleCharacterRenderer.renderInvisibleCharacter(atLocation: location, alignedTo: lineFragment, in: line)
        }
    }
}
