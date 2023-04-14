import Combine
import CoreGraphics
import Foundation

final class InvisibleCharacterSettings {
    let font: CurrentValueSubject<MultiPlatformFont, Never>
    let textColor: CurrentValueSubject<MultiPlatformColor, Never>
    let showTabs = CurrentValueSubject<Bool, Never>(false)
    let showSpaces = CurrentValueSubject<Bool, Never>(false)
    let showNonBreakingSpaces = CurrentValueSubject<Bool, Never>(false)
    let showLineBreaks = CurrentValueSubject<Bool, Never>(false)
    let showSoftLineBreaks = CurrentValueSubject<Bool, Never>(false)
    let tabSymbol = CurrentValueSubject<String, Never>("\u{25b8}")
    let spaceSymbol = CurrentValueSubject<String, Never>("\u{00b7}")
    let nonBreakingSpaceSymbol = CurrentValueSubject<String, Never>("\u{00b7}")
    let lineBreakSymbol = CurrentValueSubject<String, Never>("\u{00ac}")
    let softLineBreakSymbol = CurrentValueSubject<String, Never>("\u{00ac}")
    let maximumLineBreakSymbolWidth = CurrentValueSubject<CGFloat, Never>(0)
    let showInvisibleCharacters = CurrentValueSubject<Bool, Never>(false)

    private var cancellables: Set<AnyCancellable> = []

    init(font: CurrentValueSubject<MultiPlatformFont, Never>, textColor: CurrentValueSubject<MultiPlatformColor, Never>) {
        self.font = font
        self.textColor = textColor
        Publishers.CombineLatest3(
            font,
            Publishers.CombineLatest(showLineBreaks, showSoftLineBreaks).map {
                (lineBreaks: $0, softLineBreaks: $1)
            },
            Publishers.CombineLatest(lineBreakSymbol, softLineBreakSymbol).map {
                (lineBreakSymbol: $0, softLineBreakSymbol: $1)
            }
        )
        .removeDuplicates(by: {
            $0.0 != $1.0 && $0.1 != $1.1 && $0.2 != $1.2
        })
        .sink { [weak self] font, show, symbols in
            guard let self else {
                return
            }
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let lineBreakSymbolSize = show.lineBreaks ? symbols.lineBreakSymbol.size(withAttributes: attrs) : .zero
            let softLineBreakSymbolSize = show.softLineBreaks ? symbols.softLineBreakSymbol.size(withAttributes: attrs) : .zero
            self.maximumLineBreakSymbolWidth.value = max(lineBreakSymbolSize.width, softLineBreakSymbolSize.width)
        }.store(in: &cancellables)
        Publishers.CombineLatest4(
            showTabs,
            showSpaces,
            showLineBreaks,
            showSoftLineBreaks
        ).sink { [weak self] showTabs, showSpaces, showLineBreaks, showSoftLineBreaks in
            self?.showInvisibleCharacters.value = showTabs || showSpaces || showLineBreaks || showSoftLineBreaks
        }.store(in: &cancellables)
    }
}

