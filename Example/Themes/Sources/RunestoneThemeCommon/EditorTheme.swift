import Runestone
import UIKit

public protocol EditorTheme: Runestone.Theme {
    var backgroundColor: UIColor { get }
    var userInterfaceStyle: UIUserInterfaceStyle { get }
}
