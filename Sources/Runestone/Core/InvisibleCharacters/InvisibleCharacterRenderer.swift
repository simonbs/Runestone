#if os(macOS)
import AppKit
#endif
import Combine
import Foundation
#if os(iOS)
import UIKit
#endif

struct InvisibleCharacterRenderer {
    private enum HorizontalPosition {
        case character(Int)
        case endOfLine
    }

    private struct RenderConfiguration {
        let symbol: String
        let position: HorizontalPosition
    }

    let stringView: CurrentValueSubject<StringView, Never>
    let invisibleCharacterSettings: InvisibleCharacterSettings

    func canRenderInvisibleCharacter(atLocation location: Int, alignedTo lineFragment: LineFragment, in line: LineNode) -> Bool {
        configurationForRenderingInvisibleCharacter(atLocation: location, alignedTo: lineFragment, in: line) != nil
    }

    func renderInvisibleCharacter(atLocation location: Int, alignedTo lineFragment: LineFragment, in line: LineNode) {
        if let configuration = configurationForRenderingInvisibleCharacter(atLocation: location, alignedTo: lineFragment, in: line) {
            render(configuration.symbol, at: configuration.position, in: lineFragment)
        }
    }
}

private extension InvisibleCharacterRenderer {
    private func configurationForRenderingInvisibleCharacter(
        atLocation location: Int,
        alignedTo lineFragment: LineFragment,
        in line: LineNode
    ) -> RenderConfiguration? {
        guard invisibleCharacterSettings.showInvisibleCharacters.value else {
            return nil
        }
        let range = NSRange(location: location, length: 1)
        guard let character = stringView.value.substring(in: range)?.first else {
            return nil
        }
        let lineLocalLocation = location - line.location
        if invisibleCharacterSettings.showSpaces.value && character == Symbol.Character.space {
            return .init(symbol: invisibleCharacterSettings.spaceSymbol.value, position: .character(lineLocalLocation))
        } else if invisibleCharacterSettings.showNonBreakingSpaces.value && character == Symbol.Character.nonBreakingSpace {
            return .init(symbol: invisibleCharacterSettings.nonBreakingSpaceSymbol.value, position: .character(lineLocalLocation))
        } else if invisibleCharacterSettings.showTabs.value && character == Symbol.Character.tab {
            return .init(symbol: invisibleCharacterSettings.tabSymbol.value, position: .character(lineLocalLocation))
        } else if invisibleCharacterSettings.showLineBreaks.value && character.isLineBreak {
            return .init(symbol: invisibleCharacterSettings.lineBreakSymbol.value, position: .endOfLine)
        } else if invisibleCharacterSettings.showSoftLineBreaks.value && character == Symbol.Character.lineSeparator {
            return .init(symbol: invisibleCharacterSettings.softLineBreakSymbol.value, position: .endOfLine)
        } else {
            return nil
        }
    }

    private func render(_ symbol: String, at horizontalPosition: HorizontalPosition, in lineFragment: LineFragment) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: invisibleCharacterSettings.textColor.value,
            .font: invisibleCharacterSettings.font.value,
            .paragraphStyle: paragraphStyle
        ]
        let size = symbol.size(withAttributes: attrs)
        let xPosition = xPositionDrawingSymbol(ofSize: size, at: horizontalPosition, in: lineFragment)
        let yPosition = (lineFragment.scaledSize.height - size.height) / 2
        let rect = CGRect(x: xPosition, y: yPosition, width: size.width, height: size.height)
        symbol.draw(in: rect, withAttributes: attrs)
    }

    private func xPositionDrawingSymbol(
        ofSize symbolSize: CGSize,
        at horizontalPosition: HorizontalPosition,
        in lineFragment: LineFragment
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
