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

    private var cancellables: Set<AnyCancellable> = []

    init(font: CurrentValueSubject<MultiPlatformFont, Never>, textColor: CurrentValueSubject<MultiPlatformColor, Never>) {
        self.font = font
        self.textColor = textColor
        Publishers.CombineLatest4(
            font,
            Publishers.CombineLatest(showLineBreaks, showSoftLineBreaks).map { $0 || $1 },
            lineBreakSymbol,
            softLineBreakSymbol
        ).removeDuplicates(by: { old, new in
            old != new
        }).map { new in
            (font: new.0, lineBreakSymbol: new.2, softLineBreakSymbol: new.3)
        }.sink { [weak self] values in
            guard let self else {
                return
            }
            let attrs: [NSAttributedString.Key: Any] = [.font: values.font]
            let lineBreakSymbolSize = values.lineBreakSymbol.size(withAttributes: attrs)
            let softLineBreakSymbolSize = values.softLineBreakSymbol.size(withAttributes: attrs)
            self.maximumLineBreakSymbolWidth.value = max(lineBreakSymbolSize.width, softLineBreakSymbolSize.width)
        }.store(in: &cancellables)
    }
}

