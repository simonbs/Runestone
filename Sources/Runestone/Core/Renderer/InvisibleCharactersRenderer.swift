#if os(macOS)
import AppKit
#endif
import Foundation
#if os(iOS)
import UIKit
#endif

final class InvisibleCharactersRenderer: Renderer {
    private enum HorizontalPosition {
        case character(Int)
        case endOfLine
    }

    private let lineFragment: LineFragment
    private let stringProvider: RendererStringProvider
    private let invisibleCharacterSettings: InvisibleCharacterSettings
    private var showInvisibleCharacters: Bool {
        invisibleCharacterSettings.showTabs.value
            || invisibleCharacterSettings.showSpaces.value
            || invisibleCharacterSettings.showLineBreaks.value
            || invisibleCharacterSettings.showSoftLineBreaks.value
    }

    init(lineFragment: LineFragment, stringProvider: RendererStringProvider, invisibleCharacterSettings: InvisibleCharacterSettings) {
        self.lineFragment = lineFragment
        self.stringProvider = stringProvider
        self.invisibleCharacterSettings = invisibleCharacterSettings
    }

    func render() {
        guard showInvisibleCharacters else {
            return
        }
        guard let string = stringProvider.string else {
            return
        }
        renderInvisibleCharacters(in: string)
    }
}

private extension InvisibleCharactersRenderer {
    private func renderInvisibleCharacters(in string: String) {
        var indexInLineFragment = 0
        for substring in string {
            let indexInLine = lineFragment.visibleRange.location + indexInLineFragment
            indexInLineFragment += substring.utf16.count
            if invisibleCharacterSettings.showSpaces.value && substring == Symbol.Character.space {
                render(invisibleCharacterSettings.spaceSymbol.value, at: .character(indexInLine))
            } else if invisibleCharacterSettings.showNonBreakingSpaces.value && substring == Symbol.Character.nonBreakingSpace {
                render(invisibleCharacterSettings.nonBreakingSpaceSymbol.value, at: .character(indexInLine))
            } else if invisibleCharacterSettings.showTabs.value && substring == Symbol.Character.tab {
                render(invisibleCharacterSettings.tabSymbol.value, at: .character(indexInLine))
            } else if invisibleCharacterSettings.showLineBreaks.value && substring.isLineBreak {
                render(invisibleCharacterSettings.lineBreakSymbol.value, at: .endOfLine)
            } else if invisibleCharacterSettings.showSoftLineBreaks.value && substring == Symbol.Character.lineSeparator {
                render(invisibleCharacterSettings.softLineBreakSymbol.value, at: .endOfLine)
            }
        }
    }

    private func render(_ symbol: String, at horizontalPosition: HorizontalPosition) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: invisibleCharacterSettings.textColor.value,
            .font: invisibleCharacterSettings.font.value,
            .paragraphStyle: paragraphStyle
        ]
        let size = symbol.size(withAttributes: attrs)
        let xPosition = xPositionDrawingSymbol(ofSize: size, at: horizontalPosition)
        let yPosition = (lineFragment.scaledSize.height - size.height) / 2
        let rect = CGRect(x: xPosition, y: yPosition, width: size.width, height: size.height)
        symbol.draw(in: rect, withAttributes: attrs)
    }

    private func xPositionDrawingSymbol(ofSize symbolSize: CGSize, at horizontalPosition: HorizontalPosition) -> CGFloat {
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

