import _RunestoneMultiPlatform
import Combine
import CoreGraphics

final class ThemeSettings {
    let theme: CurrentValueSubject<Theme, Never>
    let font: CurrentValueSubject<MultiPlatformFont, Never>
    let textColor: CurrentValueSubject<MultiPlatformColor, Never>
    let invisibleCharactersColor: CurrentValueSubject<MultiPlatformColor, Never>
    let selectedLineBackgroundColor: CurrentValueSubject<MultiPlatformColor, Never>
    let pageGuideBackgroundColor: CurrentValueSubject<MultiPlatformColor, Never>
    let pageGuideHairlineColor: CurrentValueSubject<MultiPlatformColor, Never>
    let pageGuideHairlineWidth: CurrentValueSubject<CGFloat, Never>
    let markedTextBackgroundColor: CurrentValueSubject<MultiPlatformColor, Never>
    let markedTextBackgroundCornerRadius: CurrentValueSubject<CGFloat, Never>

    private var cancellables: Set<AnyCancellable> = []

    init(theme: Theme = DefaultTheme()) {
        self.theme = CurrentValueSubject(theme)
        self.font = CurrentValueSubject(theme.font)
        self.textColor = CurrentValueSubject(theme.textColor)
        self.invisibleCharactersColor = CurrentValueSubject(theme.invisibleCharactersColor)
        self.selectedLineBackgroundColor = CurrentValueSubject(theme.selectedLineBackgroundColor)
        self.pageGuideBackgroundColor = CurrentValueSubject(theme.pageGuideBackgroundColor)
        self.pageGuideHairlineColor = CurrentValueSubject(theme.pageGuideHairlineColor)
        self.pageGuideHairlineWidth = CurrentValueSubject(theme.pageGuideHairlineWidth)
        self.markedTextBackgroundColor = CurrentValueSubject(theme.markedTextBackgroundColor)
        self.markedTextBackgroundCornerRadius = CurrentValueSubject(theme.markedTextBackgroundCornerRadius)
        setupObservers()
    }
}

private extension ThemeSettings {
    private func setupObservers() {
        setupObserver(assigning: \.font, to: \.font.value)
        setupObserver(assigning: \.textColor, to: \.textColor.value)
        setupObserver(assigning: \.selectedLineBackgroundColor, to: \.selectedLineBackgroundColor.value)
        setupObserver(assigning: \.pageGuideBackgroundColor, to: \.pageGuideBackgroundColor.value)
        setupObserver(assigning: \.pageGuideHairlineColor, to: \.pageGuideHairlineColor.value)
        setupObserver(assigning: \.pageGuideHairlineWidth, to: \.pageGuideHairlineWidth.value)
        setupObserver(assigning: \.markedTextBackgroundColor, to: \.markedTextBackgroundColor.value)
        setupObserver(assigning: \.markedTextBackgroundCornerRadius, to: \.markedTextBackgroundCornerRadius.value)
    }

    private func setupObserver<T>(
        assigning sourceKeyPath: KeyPath<Theme, T>,
        to destinationKeyPath: ReferenceWritableKeyPath<ThemeSettings, T>
    ) {
        theme.map(sourceKeyPath).sink { [weak self] value in
            self?[keyPath: destinationKeyPath] = value
        }.store(in: &cancellables)
    }
}
