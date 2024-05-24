import _RunestoneObservation
#if os(macOS)
import AppKit
#endif
import Combine
import Foundation
#if os(iOS)
import UIKit
#endif

@RunestoneObserver @RunestoneObservable
final class InvisibleCharactersLineFragmentRenderer<
    State: ThemeReadable & InvisibleCharacterConfigurationReadable & Equatable,
    InvisibleCharacterRendererType: InvisibleCharacterRendering & Equatable
>: LineFragmentRendering {
    private(set) var needsDisplay = false

    private let state: State
    private let invisibleCharacterRenderer: InvisibleCharacterRendererType

    init(state: State, invisibleCharacterRenderer: InvisibleCharacterRendererType) {
        self.state = state
        self.invisibleCharacterRenderer = invisibleCharacterRenderer
        beginUpdatingNeedsDisplay(observing: state)
    }

    func render<LineType: Line>(
        _ lineFragment: LineType.LineFragmentType,
        in line: LineType,
        to context: CGContext
    ) {
        needsDisplay = false
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
                in: line,
                to: context
            )
        }
    }

    static func == (
        lhs: InvisibleCharactersLineFragmentRenderer<State, InvisibleCharacterRendererType>,
        rhs: InvisibleCharactersLineFragmentRenderer<State, InvisibleCharacterRendererType>
    ) -> Bool {
        lhs.state == rhs.state && lhs.invisibleCharacterRenderer == rhs.invisibleCharacterRenderer
    }
}

private extension InvisibleCharactersLineFragmentRenderer {
    private func beginUpdatingNeedsDisplay(observing state: State) {
        observe(state.showInvisibleCharacters) { [weak self] oldValue, newValue in
            if newValue != oldValue {
                self?.needsDisplay = true
            }
        }
        observe(state.theme) { [weak self] _, _ in
            self?.needsDisplay = true
        }
    }
}
