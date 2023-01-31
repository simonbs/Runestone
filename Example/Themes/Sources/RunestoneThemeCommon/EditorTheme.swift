#if os(macOS)
import AppKit
#endif
import Runestone
#if os(iOS)
import UIKit
#endif

public protocol EditorTheme: Runestone.Theme {
    var backgroundColor: MultiPlatformColor { get }
    #if os(iOS)
    var userInterfaceStyle: UIUserInterfaceStyle { get }
    #endif
}
