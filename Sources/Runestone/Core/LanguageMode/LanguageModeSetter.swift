import Combine

final class LanguageModeSetter {
    private let stringView: CurrentValueSubject<StringView, Never>
    private let languageMode: CurrentValueSubject<any InternalLanguageMode, Never>
    private let internalLanguageModeFactory: InternalLanguageModeFactory

    init(
        stringView: CurrentValueSubject<StringView, Never>,
        languageMode: CurrentValueSubject<any InternalLanguageMode, Never>,
        internalLanguageModeFactory: InternalLanguageModeFactory
    ) {
        self.stringView = stringView
        self.languageMode = languageMode
        self.internalLanguageModeFactory = internalLanguageModeFactory
    }

    func setLanguageMode(_ newLanguageMode: LanguageMode, completion: ((Bool) -> Void)? = nil) {
        languageMode.value = internalLanguageModeFactory.internalLanguageMode(from: newLanguageMode)
        languageMode.value.parse(stringView.value.string) { [weak self] finished in
//            if let self = self, finished {
//                self.invalidateLines()
//                self.lineFragmentLayouter.setNeedsLayout()
//                self.lineFragmentLayouter.layoutIfNeeded()
//            }
            completion?(finished)
        }
    }
}
