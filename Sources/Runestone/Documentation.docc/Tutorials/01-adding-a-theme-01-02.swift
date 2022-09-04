import UIKit

extension UIColor {
    struct Tomorrow {
        var background: UIColor {
            return .white
        }
        var selection: UIColor {
            return UIColor(red: 222 / 255, green: 222 / 255, blue: 222 / 255, alpha: 1)
        }
        var currentLine: UIColor {
            return UIColor(red: 242 / 255, green: 242 / 255, blue: 242 / 255, alpha: 1)
        }
        var foreground: UIColor {
            return UIColor(red: 96 / 255, green: 96 / 255, blue: 95 / 255, alpha: 1)
        }
        var comment: UIColor {
            return UIColor(red: 159 / 255, green: 161 / 255, blue: 158 / 255, alpha: 1)
        }
        var red: UIColor {
            return UIColor(red: 196 / 255, green: 74 / 255, blue: 62 / 255, alpha: 1)
        }
        var orange: UIColor {
            return UIColor(red: 236 / 255, green: 157 / 255, blue: 68 / 255, alpha: 1)
        }
        var yellow: UIColor {
            return UIColor(red: 232 / 255, green: 196 / 255, blue: 66 / 255, alpha: 1)
        }
        var green: UIColor {
            return UIColor(red: 136 / 255, green: 154 / 255, blue: 46 / 255, alpha: 1)
        }
        var aqua: UIColor {
            return UIColor(red: 100 / 255, green: 166 / 255, blue: 173 / 255, alpha: 1)
        }
        var blue: UIColor {
            return UIColor(red: 94 / 255, green: 133 / 255, blue: 184 / 255, alpha: 1)
        }
        var purple: UIColor {
            return UIColor(red: 149 / 255, green: 115 / 255, blue: 179 / 255, alpha: 1)
        }

        fileprivate init() {}
    }

    static let tomorrow = Tomorrow()
}
