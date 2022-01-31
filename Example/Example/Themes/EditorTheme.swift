import Runestone
import UIKit

protocol EditorTheme: Runestone.Theme {
    var backgroundColor: UIColor { get }
    var userInterfaceStyle: UIUserInterfaceStyle { get }
}
