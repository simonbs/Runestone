#if os(macOS)
import AppKit
#endif
import Runestone
#if os(iOS) || os(xrOS)
import UIKit
#endif

public protocol EditorTheme: Runestone.Theme {
    var backgroundColor: MultiPlatformColor { get }
    #if os(iOS) || os(xrOS)
    var userInterfaceStyle: UIUserInterfaceStyle { get }
    #endif
}
