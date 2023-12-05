import Combine

final class LanguageModeSetter<
    StringViewType: StringView, LineManagerType: LineManaging, LanguageModeType: InternalLanguageMode
> {
    private let stringView: StringViewType
    private let languageMode: LanguageModeType
    private let internalLanguageModeFactory: InternalLanguageModeFactory<StringViewType, LineManagerType>

    init(
        stringView: StringViewType,
        languageMode: LanguageModeType,
        internalLanguageModeFactory: InternalLanguageModeFactory<StringViewType, LineManagerType>
    ) {
        self.stringView = stringView
        self.languageMode = languageMode
        self.internalLanguageModeFactory = internalLanguageModeFactory
    }

    func setLanguageMode(_ newLanguageMode: LanguageMode, completion: ((Bool) -> Void)? = nil) {
//        languageMode = internalLanguageModeFactory.internalLanguageMode(from: newLanguageMode)
//        languageMode.parse(stringView.string) { [weak self] finished in
//            if let self = self, finished {
//                self.invalidateLines()
//                self.lineFragmentLayouter.setNeedsLayout()
//                self.lineFragmentLayouter.layoutIfNeeded()
//            }
//            completion?(finished)
//        }
    }
}
