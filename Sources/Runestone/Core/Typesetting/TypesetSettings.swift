import Combine
import CoreGraphics

final class TypesetSettings {
    let isLineWrappingEnabled = CurrentValueSubject<Bool, Never>(false)
    let lineHeightMultiplier = CurrentValueSubject<CGFloat, Never>(1)
    let lineBreakMode = CurrentValueSubject<LineBreakMode, Never>(.byWordWrapping)
    let kern = CurrentValueSubject<CGFloat, Never>(0)
    let tabWidth: CurrentValueSubject<CGFloat, Never>
    let lineEndings = CurrentValueSubject<LineEnding, Never>(.lf)
    let indentStrategy = CurrentValueSubject<IndentStrategy, Never>(.tab(length: 2))

    private var cancellables: Set<AnyCancellable> = []

    init(font: CurrentValueSubject<MultiPlatformFont, Never>) {
        let rawTabWidth = TabWidthMeasurer.measure(lengthInSpaces: indentStrategy.value.lengthInSpaces, font: font.value)
        tabWidth = CurrentValueSubject(rawTabWidth)
        setupTabWidthObserver(font: font)
    }
}

private extension TypesetSettings {
    private func setupTabWidthObserver(font: CurrentValueSubject<MultiPlatformFont, Never>) {
        Publishers.CombineLatest(indentStrategy, font).dropFirst().sink { [weak self] indentStrategy, font in
            if let self {
                self.tabWidth.value = TabWidthMeasurer.measure(lengthInSpaces: indentStrategy.lengthInSpaces, font: font)
            }
        }.store(in: &cancellables)
    }
}
