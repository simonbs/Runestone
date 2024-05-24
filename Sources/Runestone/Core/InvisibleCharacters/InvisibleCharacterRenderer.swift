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
final class InvisibleCharacterRenderer<
    StringViewType: StringView,
    State: ThemeReadable & InvisibleCharacterConfigurationReadable & Equatable
>: InvisibleCharacterRendering, Equatable {
    private enum HorizontalPosition {
        case character(Int)
        case endOfLine
    }

    private struct RenderConfiguration {
        let symbol: String
        let position: HorizontalPosition
    }

    private let state: State
    private let stringView: StringViewType

    init(state: State, stringView: StringViewType) {
        self.state = state
        self.stringView = stringView
    }

    func canRenderInvisibleCharacter<LineType: Line>(
        atLocation location: Int,
        alignedTo lineFragment: LineType.LineFragmentType,
        in line: LineType
    ) -> Bool {
        let configuration = configurationForRenderingInvisibleCharacter(
            atLocation: location, 
            alignedTo: lineFragment,
            in: line
        )
        return configuration != nil
    }

    func renderInvisibleCharacter<LineType: Line>(
        atLocation location: Int,
        alignedTo lineFragment: LineType.LineFragmentType,
        in line: LineType,
        to context: CGContext
    ) {
        guard let configuration = configurationForRenderingInvisibleCharacter(
            atLocation: location,
            alignedTo: lineFragment,
            in: line
        ) else {
            return
        }
        render(configuration.symbol, at: configuration.position, in: lineFragment, to: context)
    }

    static func == (
        lhs: InvisibleCharacterRenderer<StringViewType, State>,
        rhs: InvisibleCharacterRenderer<StringViewType, State>
    ) -> Bool {
        lhs.state == rhs.state && lhs.stringView == rhs.stringView
    }
}

private extension InvisibleCharacterRenderer {
    private func configurationForRenderingInvisibleCharacter<LineType: Line>(
        atLocation location: Int,
        alignedTo lineFragment: LineType.LineFragmentType,
        in line: LineType
    ) -> RenderConfiguration? {
        guard state.showInvisibleCharacters else {
            return nil
        }
        let range = NSRange(location: location, length: 1)
        guard let character = stringView.substring(in: range)?.first else {
            return nil
        }
        let lineLocalLocation = location - line.location
        if state.showSpaces && character == Symbol.Character.space {
            return .init(symbol: state.spaceSymbol, position: .character(lineLocalLocation))
        } else if state.showNonBreakingSpaces && character == Symbol.Character.nonBreakingSpace {
            return .init(symbol: state.nonBreakingSpaceSymbol, position: .character(lineLocalLocation))
        } else if state.showTabs && character == Symbol.Character.tab {
            return .init(symbol: state.tabSymbol, position: .character(lineLocalLocation))
        } else if state.showLineBreaks && character.isLineBreak {
            return .init(symbol: state.lineBreakSymbol, position: .endOfLine)
        } else if state.showSoftLineBreaks && character == Symbol.Character.lineSeparator {
            return .init(symbol: state.softLineBreakSymbol, position: .endOfLine)
        } else {
            return nil
        }
    }

    private func render(
        _ symbol: String,
        at horizontalPosition: HorizontalPosition,
        in lineFragment: some LineFragment,
        to context: CGContext
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: state.theme.invisibleCharactersColor,
            .font: state.theme.font,
            .paragraphStyle: paragraphStyle
        ]
        let size = symbol.size(withAttributes: attrs)
        let xPosition = xPositionDrawingSymbol(ofSize: size, at: horizontalPosition, in: lineFragment)
        let yPosition = (lineFragment.scaledSize.height - size.height) / 2
        let rect = CGRect(x: xPosition, y: yPosition, width: size.width, height: size.height)
        context.asCurrent {
            symbol.draw(in: rect, withAttributes: attrs)
        }
    }

    private func xPositionDrawingSymbol(
        ofSize symbolSize: CGSize,
        at horizontalPosition: HorizontalPosition,
        in lineFragment: some LineFragment
    ) -> CGFloat {
        switch horizontalPosition {
        case .character(let index):
            let minX = CTLineGetOffsetForStringIndex(lineFragment.line, index, nil)
            if index < lineFragment.range.upperBound {
                let maxX = CTLineGetOffsetForStringIndex(lineFragment.line, index + 1, nil)
                return minX + (maxX - minX - symbolSize.width) / 2
            } else {
                return minX
            }
        case .endOfLine:
            return CGFloat(CTLineGetTypographicBounds(lineFragment.line, nil, nil, nil))
        }
    }
}
