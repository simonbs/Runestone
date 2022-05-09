import Runestone
import RunestoneOneDarkTheme
import RunestonePlainTextTheme
import RunestoneThemeCommon
import RunestoneTomorrowNightTheme
import RunestoneTomorrowTheme

enum ThemeSetting: String, CaseIterable, Hashable {
    case oneDark
    case plainText
    case tomorrow
    case tomorrowNight

    var title: String {
        switch self {
        case .oneDark:
            return "One Dark"
        case .plainText:
            return "Plain Text"
        case .tomorrow:
            return "Tomorrow"
        case .tomorrowNight:
            return "Tomorrow Night"
        }
    }

    func makeTheme() -> EditorTheme {
        switch self {
        case .oneDark:
            return OneDarkTheme()
        case .plainText:
            return PlainTextTheme()
        case .tomorrow:
            return TomorrowTheme()
        case .tomorrowNight:
            return TomorrowNightTheme()
        }
    }
}
